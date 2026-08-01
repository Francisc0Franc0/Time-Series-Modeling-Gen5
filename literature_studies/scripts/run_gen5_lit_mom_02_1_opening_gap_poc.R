# Run the frozen LIT-MOM-02.1 opening-gap POC and wide atlas.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."),
                winslash = "/", mustWork = FALSE)
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
  "gen5_lit_mom_02_1_opening_gap_poc.R"
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
    stop("Could not create LIT-MOM-02.1 output directory.", call. = FALSE)
  }
}

write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}

read_or_fetch_daily <- function(
  path, symbols, start_date, end_date, contract, config, refresh
) {
  if (file.exists(path) && !refresh) {
    message("Reusing daily evidence cache: ", path)
    return(readRDS(path))
  }
  request <- g5_alpaca_daily_adjusted_request(
    symbols = unique(symbols),
    start_date = start_date,
    end_date = end_date,
    as_of_timestamp = contract$as_of_timestamp,
    latest_completed_session = end_date,
    feed = config$feed
  )
  bars <- g5_fetch_alpaca_daily_adjusted_bars(request, config)
  bars <- g5_validate_bar_data(bars)
  saveRDS(bars, path)
  bars
}

read_or_fetch_entries <- function(
  path, manifest, contract, config, adjustment_asof, refresh
) {
  if (file.exists(path) && !refresh) {
    message("Reusing 09:32 evidence cache: ", path)
    return(readRDS(path))
  }
  entries <- g5_mr06_alpaca_fetch_entries(
    manifest = manifest,
    contract = contract,
    config = config,
    adjustment_asof = adjustment_asof,
    progress_every = 25L
  )
  saveRDS(entries, path)
  entries
}

coverage_table <- function(bars, symbols, start_date, end_date) {
  reference <- sort(unique(bars$session_date[
    bars$symbol == "SPY" & bars$session_date >= start_date &
      bars$session_date <= end_date
  ]))
  do.call(rbind, lapply(symbols, function(symbol) {
    observed <- sort(unique(bars$session_date[
      bars$symbol == symbol & bars$session_date >= start_date &
        bars$session_date <= end_date
    ]))
    data.frame(
      symbol = symbol,
      observed_sessions = length(observed),
      reference_sessions = length(reference),
      coverage_rate = length(intersect(observed, reference)) /
        max(1L, length(reference)),
      first_session = if (length(observed)) min(observed) else as.Date(NA),
      last_session = if (length(observed)) max(observed) else as.Date(NA),
      stringsAsFactors = FALSE
    )
  }))
}

with_png <- function(path, width, height, expr) {
  grDevices::png(path, width = width, height = height, res = 140)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(expr)
}

plot_mechanics <- function(path) {
  with_png(path, 1800, 950, {
    old <- par(mar = c(4, 5, 4, 2))
    on.exit(par(old), add = TRUE)
    x <- 1:7
    prior_high <- 100
    prior_low <- 96
    threshold_up <- 101
    threshold_down <- 95
    values <- c(98, 99.5, 100, 102.2, 103.1, 102.5, 104)
    plot(
      x, values, type = "o", pch = 19, lwd = 4, col = "#3D8DFF",
      xaxt = "n", xlab = "", ylab = "Illustrative price",
      main = "Opening-gap momentum: cross yesterday's extreme, then test continuation",
      ylim = c(94, 105)
    )
    axis(1, at = x, labels = c(
      "Prior open", "Prior mid", "Prior close", "Open", "09:32",
      "Midday", "Close"
    ))
    abline(h = prior_high, lty = 2, lwd = 2, col = "#64748B")
    abline(h = threshold_up, lty = 3, lwd = 3, col = "#177245")
    abline(h = prior_low, lty = 2, lwd = 2, col = "#64748B")
    abline(h = threshold_down, lty = 3, lwd = 3, col = "#B42318")
    text(6.7, prior_high + 0.2, "Prior high", adj = 1, col = "#64748B")
    text(6.7, threshold_up + 0.2, "Long threshold", adj = 1, col = "#177245")
    arrows(4, values[[4]], 5, values[[5]], length = 0.12, lwd = 3,
           col = "#123047")
    text(4.5, 103.6, "Observe 09:31 -> enter 09:32", cex = 1.1)
  })
}

plot_gate_heatmap <- function(gates, summary, path, poc_only = FALSE) {
  ids <- if (poc_only) summary$instance_id[summary$poc_anchor] else {
    summary$instance_id
  }
  labels <- summary$symbol[match(ids, summary$instance_id)]
  matrix <- sapply(ids, function(id) {
    as.integer(gates$status[gates$instance_id == id] == "PASS")
  })
  if (is.null(dim(matrix))) matrix <- matrix(matrix, ncol = 1L)
  rownames(matrix) <- paste0("G", seq_len(nrow(matrix)))
  colnames(matrix) <- labels
  width <- if (poc_only) 1500 else 2600
  with_png(path, width, if (poc_only) 850 else 1200, {
    old <- par(mar = c(if (poc_only) 6 else 8, 5, 4, 2))
    on.exit(par(old), add = TRUE)
    image(
      seq_len(ncol(matrix)), seq_len(nrow(matrix)), t(matrix),
      col = c("#D95F59", "#2E8B57"), axes = FALSE,
      xlab = "", ylab = "", main = if (poc_only) {
        "Small POC: eight frozen TRAIN gates"
      } else "Wide atlas: the same eight gates for every instrument"
    )
    axis(1, at = seq_len(ncol(matrix)), labels = colnames(matrix),
         las = 2, cex.axis = if (poc_only) 1 else 0.55)
    axis(2, at = seq_len(nrow(matrix)), labels = rownames(matrix), las = 2)
  })
}

plot_return_intervals <- function(summary, path, poc_only = FALSE) {
  x <- if (poc_only) summary[summary$poc_anchor, , drop = FALSE] else {
    summary
  }
  if (!poc_only) {
    x <- x[order(x$mean_primary_event_return, decreasing = TRUE), , drop = FALSE]
    x <- rbind(head(x, 15L), tail(x, 10L))
  }
  x <- x[order(x$mean_primary_event_return), , drop = FALSE]
  limits <- range(c(
    x$bootstrap_lower_90, x$mean_primary_event_return, 0
  ), finite = TRUE) * 10000
  with_png(path, 1700, if (poc_only) 900 else 1350, {
    old <- par(mar = c(5, 8, 4, 2))
    on.exit(par(old), add = TRUE)
    y <- seq_len(nrow(x))
    plot(
      x$mean_primary_event_return * 10000, y,
      xlim = limits, yaxt = "n", ylab = "",
      xlab = "Primary-cost mean return (bp per event)", pch = 19,
      col = "#123047", main = if (poc_only) {
        "Small POC: mean continuation and one-sided 90% lower bounds"
      } else "Atlas tails: strongest and weakest TRAIN estimates"
    )
    segments(
      x$bootstrap_lower_90 * 10000, y,
      x$mean_primary_event_return * 10000, y,
      lwd = 4, col = "#3D8DFF"
    )
    abline(v = 0, lty = 2, col = "#B42318")
    axis(2, at = y, labels = x$symbol, las = 2)
  })
}

plot_accuracy_payoff <- function(summary, path) {
  cols <- grDevices::hcl.colors(length(unique(summary$category)), "Dark 3")
  names(cols) <- unique(summary$category)
  with_png(path, 1800, 1150, {
    old <- par(mar = c(5, 5, 4, 2))
    on.exit(par(old), add = TRUE)
    plot(
      100 * summary$direction_accuracy,
      10000 * summary$mean_primary_event_return,
      pch = ifelse(summary$full_pass, 17, 19),
      cex = ifelse(summary$poc_anchor, 1.7, 1.0),
      col = cols[summary$category],
      xlab = "Direction accuracy (%)",
      ylab = "Primary-cost mean (bp/event)",
      main = "Correct direction is necessary, but payoff and uncertainty still matter"
    )
    abline(v = 50, h = 0, lty = 2, col = "#64748B")
    legend("topleft", legend = names(cols), col = cols, pch = 19,
           cex = 0.7, bty = "n", ncol = 2)
  })
}

plot_source_causal <- function(summary, path) {
  x <- summary[summary$poc_anchor, , drop = FALSE]
  values <- rbind(
    x$source_same_open_cumulative_return,
    x$cumulative_return,
    x$stress_cumulative_return
  ) * 100
  colnames(values) <- x$symbol
  rownames(values) <- c("Same-open reference", "09:32 primary", "09:32 stress")
  with_png(path, 1800, 1000, {
    old <- par(mar = c(6, 5, 4, 2))
    on.exit(par(old), add = TRUE)
    barplot(
      values, beside = TRUE,
      col = c("#94A3B8", "#3D8DFF", "#F59E0B"),
      ylab = "Cumulative TRAIN return (%)",
      main = "Same-open accounting is a reference; delayed execution is the test"
    )
    abline(h = 0, col = "#123047")
    legend("topright", legend = rownames(values),
           fill = c("#94A3B8", "#3D8DFF", "#F59E0B"), bty = "n")
  })
}

plot_category_summary <- function(summary, path) {
  rows <- lapply(split(summary, summary$category), function(x) {
    data.frame(
      category = unique(x$category),
      instruments = nrow(x),
      full_pass = sum(x$full_pass),
      median_mean_bp = stats::median(x$mean_primary_event_return, na.rm = TRUE) *
        10000,
      median_accuracy = stats::median(x$direction_accuracy, na.rm = TRUE) * 100,
      stringsAsFactors = FALSE
    )
  })
  x <- do.call(rbind, rows)
  x <- x[order(x$median_mean_bp), , drop = FALSE]
  with_png(path, 1700, 1000, {
    old <- par(mar = c(6, 18, 4, 5))
    on.exit(par(old), add = TRUE)
    y <- seq_len(nrow(x))
    plot(
      x$median_mean_bp, y, pch = 19, cex = 1.5,
      xlab = "Median primary-cost mean (bp/event)", ylab = "", yaxt = "n",
      col = ifelse(x$full_pass > 0, "#177245", "#3D8DFF"),
      main = "Category medians describe breadth; they do not select a rescue lane"
    )
    abline(v = 0, lty = 2, col = "#B42318")
    axis(2, at = y, labels = paste0(
      x$category, "  (", x$instruments, "; pass ", x$full_pass, ")"
    ), las = 2)
  })
  x
}

plot_representative_events <- function(events, path) {
  valid <- events[events$entry_available, , drop = FALSE]
  if (!nrow(valid)) return(invisible(NULL))
  idx <- unique(c(
    order(valid$primary_net_return, decreasing = TRUE)[1:4],
    order(valid$primary_net_return, decreasing = FALSE)[1:4]
  ))
  x <- valid[idx, , drop = FALSE]
  with_png(path, 1900, 1050, {
    old <- par(mfrow = c(2, 4), mar = c(4, 4, 3, 1))
    on.exit(par(old), add = TRUE)
    for (i in seq_len(nrow(x))) {
      base <- if (x$position[[i]] > 0) x$prior_high[[i]] else x$prior_low[[i]]
      values <- 100 * c(
        0,
        x$open[[i]] / base - 1,
        x$entry_open[[i]] / base - 1,
        x$close[[i]] / base - 1
      )
      plot(
        seq_along(values), values, type = "o", pch = 19, lwd = 3,
        col = ifelse(x$primary_net_return[[i]] > 0, "#177245", "#B42318"),
        xaxt = "n", xlab = "", ylab = "% vs prior extreme",
        main = paste(x$symbol[[i]], x$session_date[[i]],
                     ifelse(x$position[[i]] > 0, "LONG", "SHORT"))
      )
      axis(1, at = 1:4, labels = c("Prior", "Open", "09:32", "Close"),
           cex.axis = 0.75)
      abline(h = 0, lty = 3, col = "#64748B")
    }
  })
}

registry_path <- file.path(
  repo_root, "literature_studies", "registries",
  "gen5_lit_mom_02_1_opening_gap_atlas_registry.csv"
)
registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
registry$poc_anchor <- as.logical(registry$poc_anchor)
registry <- g5_mom02_validate_registry(registry)
contract <- g5_mom02_contract(registry)
g5_mom02_validate_contract(contract)

config <- g5_alpaca_config_from_env()
g5_alpaca_preflight_live_fetch(config)

run_id <- env_or(
  "GEN5_LIT_MOM_02_1_RUN_ID",
  "lit_mom_02_1_opening_gap_atlas_01_20260801"
)
output_root <- normalizePath(env_or(
  "GEN5_LIT_MOM_02_1_OUTPUT_ROOT",
  file.path(repo_root, "runs", "research_workbench", "literature_grounded", run_id)
), winslash = "/", mustWork = FALSE)
visual_root <- file.path(output_root, "visuals")
ensure_dir(output_root)
ensure_dir(visual_root)

refresh_daily <- env_bool("GEN5_LIT_MOM_02_1_REFRESH_DAILY", FALSE)
refresh_entries <- env_bool("GEN5_LIT_MOM_02_1_REFRESH_ENTRIES", FALSE)

train_daily_path <- file.path(output_root, "train_daily_adjusted_bars.rds")
train_daily <- read_or_fetch_daily(
  train_daily_path, registry$symbol, contract$query_start, contract$train_end,
  contract, config, refresh_daily
)
train_features <- g5_mom02_feature_panel(
  g5_mom02_validate_daily(train_daily, contract, contract$train_end), contract
)
train_raw_events <- g5_mom02_signal_events(
  train_features, registry, contract$train_start, contract$train_end
)
train_manifest <- g5_mom02_entry_manifest(train_raw_events)
train_entries_path <- file.path(output_root, "train_0932_adjusted_entries.rds")
train_entries <- read_or_fetch_entries(
  train_entries_path, train_manifest, contract, config,
  contract$train_end, refresh_entries
)
train <- g5_mom02_run_phase(
  train_daily, train_entries, registry, contract,
  contract$train_start, contract$train_end, "TRAIN"
)

train_summary <- g5_mom02_summary(train)
train_gates <- g5_mom02_gate_table(train)
train_integrity <- g5_mom02_integrity_table(train)
train_years <- g5_mom02_years_table(train)
train_coverage <- coverage_table(
  train_daily, registry$symbol, contract$train_start, contract$train_end
)

write_csv(registry, file.path(output_root, "frozen_registry.csv"))
write_csv(train_manifest, file.path(output_root, "train_entry_manifest.csv"))
write_csv(train_entries, file.path(output_root, "train_entry_bars.csv"))
write_csv(train_coverage, file.path(output_root, "train_daily_coverage.csv"))
write_csv(train_summary, file.path(output_root, "train_atlas_summary.csv"))
write_csv(
  train_summary[train_summary$poc_anchor, , drop = FALSE],
  file.path(output_root, "train_small_poc_summary.csv")
)
write_csv(train_gates, file.path(output_root, "train_atlas_gates.csv"))
write_csv(train_integrity, file.path(output_root, "train_atlas_integrity.csv"))
write_csv(train_years, file.path(output_root, "train_year_summary.csv"))
write_csv(train$events, file.path(output_root, "train_event_tape.csv"))

development <- NULL
development_summary <- data.frame()
development_gates <- data.frame()
if (length(train$full_pass)) {
  nominee_registry <- registry[
    registry$instance_id %in% train$full_pass, , drop = FALSE
  ]
  development_symbols <- unique(c("SPY", nominee_registry$symbol))
  development_query_start <- as.Date("2020-08-01")
  development_daily_path <- file.path(
    output_root, "development_daily_adjusted_bars.rds"
  )
  development_daily <- read_or_fetch_daily(
    development_daily_path, development_symbols, development_query_start,
    contract$development_end, contract, config, refresh_daily
  )
  development_features <- g5_mom02_feature_panel(
    g5_mom02_validate_daily(
      development_daily, contract, contract$development_end
    ), contract
  )
  development_raw_events <- g5_mom02_signal_events(
    development_features, nominee_registry,
    contract$development_start, contract$development_end
  )
  development_manifest <- g5_mom02_entry_manifest(development_raw_events)
  development_entries_path <- file.path(
    output_root, "development_0932_adjusted_entries.rds"
  )
  development_entries <- read_or_fetch_entries(
    development_entries_path, development_manifest, contract, config,
    contract$development_end, refresh_entries
  )
  development <- g5_mom02_run_phase(
    development_daily, development_entries, nominee_registry, contract,
    contract$development_start, contract$development_end, "DEVELOPMENT"
  )
  development_summary <- g5_mom02_summary(development)
  development_gates <- g5_mom02_gate_table(development)
  write_csv(
    development_manifest,
    file.path(output_root, "development_entry_manifest.csv")
  )
  write_csv(
    development_entries,
    file.path(output_root, "development_entry_bars.csv")
  )
  write_csv(
    development_summary,
    file.path(output_root, "development_summary.csv")
  )
  write_csv(
    development_gates,
    file.path(output_root, "development_descriptive_gates.csv")
  )
  write_csv(
    development$events,
    file.path(output_root, "development_event_tape.csv")
  )
}

category_summary <- plot_category_summary(
  train_summary, file.path(visual_root, "mom02_category_summary.png")
)
write_csv(category_summary, file.path(output_root, "train_category_summary.csv"))
plot_mechanics(file.path(visual_root, "mom02_mechanics.png"))
plot_gate_heatmap(
  train_gates, train_summary,
  file.path(visual_root, "mom02_small_poc_gate_heatmap.png"), TRUE
)
plot_gate_heatmap(
  train_gates, train_summary,
  file.path(visual_root, "mom02_atlas_gate_heatmap.png"), FALSE
)
plot_return_intervals(
  train_summary,
  file.path(visual_root, "mom02_small_poc_return_intervals.png"), TRUE
)
plot_return_intervals(
  train_summary,
  file.path(visual_root, "mom02_atlas_return_tails.png"), FALSE
)
plot_accuracy_payoff(
  train_summary, file.path(visual_root, "mom02_accuracy_payoff.png")
)
plot_source_causal(
  train_summary, file.path(visual_root, "mom02_source_vs_causal.png")
)
plot_representative_events(
  train$events[train$events$poc_anchor, , drop = FALSE],
  file.path(visual_root, "mom02_representative_events.png")
)

run_spec <- data.frame(
  schema_version = contract$schema_version,
  literature_id = contract$literature_id,
  atlas_id = contract$atlas_id,
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  source_instrument = "FSTX",
  source_period = "2004-07-16/2012-05-17",
  source_role = "SOURCE_REFERENCE_ONLY",
  source_reported_apr = 0.13,
  source_reported_sharpe = 1.4,
  train_start = contract$train_start,
  train_end = contract$train_end,
  train_status = train$status,
  train_nominees = paste(train$full_pass, collapse = ","),
  development_status = if (is.null(development)) {
    "NOT_OPENED_NO_TRAIN_NOMINEE"
  } else development$status,
  confirmation_start = contract$confirmation_start,
  confirmation_status = "SEALED",
  stringsAsFactors = FALSE
)
write_csv(run_spec, file.path(output_root, "run_spec.csv"))

report <- c(
  "# LIT-MOM-02.1 Opening-Gap Momentum Report",
  "",
  paste("Status:", train$status),
  "",
  "## Frozen translation",
  "",
  "- Long an opening gap above the prior high plus 0.1 times lagged 90-session volatility.",
  "- Short an opening gap below the prior low minus 0.1 times lagged 90-session volatility.",
  "- Observe 09:31 ET, enter at the 09:32 adjusted minute-bar open, exit at the close.",
  "- Same-open and literal printed-sign results are diagnostics only.",
  "",
  "## TRAIN readout",
  "",
  paste0("- Small POC full passes: ", sum(
    train_summary$full_pass & train_summary$poc_anchor
  ), " / 8."),
  paste0("- Wide atlas full passes: ", sum(train_summary$full_pass),
         " / ", nrow(train_summary), "."),
  paste0("- TRAIN nominees: `", paste(train$full_pass, collapse = ","), "`."),
  "",
  "## Development boundary",
  "",
  paste0("- ", run_spec$development_status, "."),
  "- Confirmation beginning 2024-01-02 remains sealed.",
  "",
  "## Source boundary",
  "",
  paste(
    "Mechanics derive from Ernest P. Chan, *Algorithmic Trading* (2013),",
    "Example 7.1, printed pages 156-157 / PDF pages 174-175. The causal",
    "delay, retail registry, costs, gates, and conclusions are Gen5 design."
  )
)
writeLines(report, file.path(output_root, "lit_mom_02_1_report.md"),
           useBytes = TRUE)

message("LIT-MOM-02.1 TRAIN status: ", train$status)
message("Small POC passes: ", sum(
  train_summary$full_pass & train_summary$poc_anchor
), "/8")
message("Wide atlas passes: ", sum(train_summary$full_pass), "/", nrow(train_summary))
message("Development status: ", run_spec$development_status)
message("Evidence packet: ", output_root)
