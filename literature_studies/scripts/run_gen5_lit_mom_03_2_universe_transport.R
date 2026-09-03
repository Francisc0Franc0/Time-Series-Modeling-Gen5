# Run the frozen LIT-MOM-03.2 cross-universe transport POCs.

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
  "gen5_lit_mom_03_2_universe_transport.R"
))
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
  if (!dir.exists(path)) stop("Could not create LIT-MOM-03.2 output directory.", call. = FALSE)
}

write_csv <- function(x, path) {
  utils::write.csv(as.data.frame(x), path, row.names = FALSE, na = "")
  invisible(path)
}

contract_table <- function(contract) {
  data.frame(
    field = names(contract),
    value = vapply(contract, function(value) paste(value, collapse = ","), character(1)),
    stringsAsFactors = FALSE
  )
}

health_maximum <- function(health) {
  if (!nrow(health)) return("PASS")
  severity <- toupper(as.character(health$severity))
  rank <- c(PASS = 1L, INFO = 1L, WARN = 2L, ERROR = 3L)
  observed <- unname(rank[severity])
  observed[is.na(observed)] <- 3L
  names(rank)[which(rank == max(observed))[1L]]
}

pretty_label <- function(x) {
  labels <- c(ETF_US_SECTOR_ROTATION = "U.S. sector ETFs")
  out <- ifelse(x %in% names(labels), labels[x], gsub(" stocks$", "", x))
  unname(out)
}

short_universe_label <- function(summary) {
  labels <- c(
    "Communication Services" = "Comm. Services",
    "Consumer Discretionary" = "Cons. Discretionary",
    "Consumer Staples" = "Cons. Staples",
    "Energy" = "Energy",
    "Financials" = "Financials",
    "Health Care" = "Health Care",
    "Industrials" = "Industrials",
    "Information Technology" = "Technology",
    "Materials" = "Materials",
    "Real Estate" = "Real Estate",
    "Utilities" = "Utilities"
  )
  ifelse(
    summary$universe_type == "ETF_FLEET",
    "Sector ETFs",
    unname(labels[summary$sector])
  )
}

theme_colors <- list(
  ink = "#101820",
  blue = "#3D8DFF",
  light_blue = "#6DCBF4",
  green = "#2E7D5B",
  orange = "#C8553D",
  gray = "#8B95A1",
  grid = "#D9E2EA"
)

open_png <- function(path) {
  grDevices::png(path, width = 1800, height = 1050, res = 150, bg = "white")
  graphics::par(family = "sans", col.axis = theme_colors$ink, col.lab = theme_colors$ink)
}

render_source_vs_equal <- function(summary, path) {
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  x <- 100 * summary$equal_weight_cagr
  y <- 100 * summary$source_cagr
  lim <- range(c(x, y), finite = TRUE)
  pad <- diff(lim) * 0.12
  lim <- lim + c(-pad, pad)
  colors <- ifelse(summary$universe_type == "ETF_FLEET", theme_colors$orange, theme_colors$blue)
  graphics::plot(
    x, y, type = "n", xlim = lim, ylim = lim,
    xlab = "Equal-weight universe CAGR (%)",
    ylab = "Dual-momentum CAGR (%)",
    main = "Does rotation improve on owning the whole fleet?",
    cex.main = 1.35, cex.lab = 1.05
  )
  graphics::abline(0, 1, col = theme_colors$gray, lty = 2, lwd = 2)
  graphics::grid(col = theme_colors$grid)
  graphics::points(x, y, pch = 19, cex = 1.35, col = colors)
  labels <- short_universe_label(summary)
  label_position <- ifelse(y >= x, 3, 1)
  graphics::text(
    x, y, labels = labels, pos = label_position,
    cex = 0.68, col = theme_colors$ink, offset = 0.62
  )
  graphics::legend(
    "topleft", legend = c("ETF fleet", "Static stock-sector POC"),
    pch = 19, col = c(theme_colors$orange, theme_colors$blue), bty = "n"
  )
}

render_drawdown_control <- function(summary, path) {
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  x <- 100 * summary$equal_weight_max_drawdown
  y <- 100 * summary$source_max_drawdown
  lim <- range(c(x, y), finite = TRUE)
  pad <- diff(lim) * 0.12
  lim <- lim + c(-pad, pad)
  colors <- ifelse(summary$universe_type == "ETF_FLEET", theme_colors$orange, theme_colors$green)
  graphics::plot(
    x, y, type = "n", xlim = lim, ylim = lim,
    xlab = "",
    ylab = "Dual-momentum maximum drawdown (%)",
    main = "Points above the diagonal have shallower drawdowns",
    cex.main = 1.35, cex.lab = 1.05
  )
  graphics::abline(0, 1, col = theme_colors$gray, lty = 2, lwd = 2)
  graphics::grid(col = theme_colors$grid)
  graphics::points(x, y, pch = 19, cex = 1.35, col = colors)
  labels <- short_universe_label(summary)
  label_position <- ifelse(y >= x, 3, 1)
  graphics::text(
    x, y, labels = labels, pos = label_position,
    cex = 0.68, col = theme_colors$ink, offset = 0.62
  )
  graphics::mtext("Equal-weight maximum drawdown (%)", side = 1, line = 2.8, cex = 1.05)
}

render_component_attribution <- function(summary, path) {
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  values <- 100 * summary$source_minus_relative_cagr
  labels <- ifelse(summary$universe_type == "ETF_FLEET", "U.S. sector ETFs", summary$sector)
  order_index <- order(values)
  values <- values[order_index]
  labels <- labels[order_index]
  colors <- ifelse(values >= 0, theme_colors$green, theme_colors$orange)
  graphics::par(mar = c(5, 13, 4, 2))
  positions <- graphics::barplot(
    values, names.arg = labels, horiz = TRUE, las = 1, col = colors,
    border = NA, xlim = c(min(values) * 1.06, 0.15),
    xlab = "Dual momentum minus relative-only CAGR (percentage points)",
    main = "Did the absolute-momentum gate add anything?",
    cex.names = 0.72, cex.main = 1.35
  )
  graphics::abline(v = 0, col = theme_colors$ink, lwd = 1.5)
  graphics::text(
    x = values / 2,
    y = positions,
    labels = sprintf("%+.2f", values),
    cex = 0.72, col = "white", font = 2
  )
}

render_transport_scorecard <- function(summary, path) {
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  labels <- ifelse(summary$universe_type == "ETF_FLEET", "U.S. sector ETFs", summary$sector)
  values <- cbind(
    `CAGR vs equal` = 100 * summary$source_minus_equal_cagr,
    `Drawdown vs equal` = 100 * summary$drawdown_improvement_vs_equal,
    `CAGR vs SPY` = 100 * summary$source_minus_spy_cagr,
    `Absolute gate` = 100 * summary$source_minus_relative_cagr
  )
  max_abs <- max(abs(values), na.rm = TRUE)
  scaled <- values / max_abs
  scaled[scaled < -1] <- -1
  scaled[scaled > 1] <- 1
  palette <- grDevices::colorRampPalette(c(theme_colors$orange, "#F5F7F9", theme_colors$green))(201)
  color_index <- round((scaled + 1) * 100) + 1L
  graphics::par(mar = c(8, 13, 4, 3))
  graphics::image(
    x = seq_len(ncol(values)), y = seq_len(nrow(values)),
    z = t(scaled[nrow(values):1, , drop = FALSE]),
    col = palette, axes = FALSE,
    xlab = "", ylab = "",
    main = "Descriptive transport scorecard (percentage-point differences)"
  )
  graphics::axis(1, at = seq_len(ncol(values)), labels = colnames(values), las = 2)
  graphics::axis(2, at = seq_len(nrow(values)), labels = rev(labels), las = 1)
  for (row in seq_len(nrow(values))) {
    for (column in seq_len(ncol(values))) {
      display_row <- nrow(values) - row + 1L
      color <- palette[color_index[row, column]]
      graphics::rect(column - 0.5, display_row - 0.5, column + 0.5, display_row + 0.5,
        col = color, border = "white")
      graphics::text(column, display_row, sprintf("%+.2f", values[row, column]), cex = 0.82)
    }
  }
  graphics::box()
}

write_report <- function(result, paths, run_spec) {
  summary <- result$summary
  etf <- summary[summary$universe_type == "ETF_FLEET", , drop = FALSE]
  stock <- summary[summary$universe_type == "STATIC_STOCK_SECTOR", , drop = FALSE]
  best <- stock[order(-stock$source_minus_equal_cagr), , drop = FALSE][1L, ]
  worst <- stock[order(stock$source_minus_equal_cagr), , drop = FALSE][1L, ]
  lines <- c(
    "# LIT-MOM-03.2 universe-transport POCs",
    "",
    paste("Status:", run_spec$overall_status),
    "",
    "## Question",
    "",
    "Does the frozen 10/25-week, top-three, positive-only rotation principle retain an interesting shape when only the ranking universe changes?",
    "",
    "## Frozen breadth",
    "",
    "- One ten-member U.S. sector-ETF fleet.",
    "- Eleven eight-member stock-sector fleets from the pre-existing long-history atlas.",
    "- The stock fleets are static survivor-biased exploratory POCs, not point-in-time membership evidence.",
    "- Every fleet uses the same Wednesday-close signal, next-open execution, 5 bps one-way cost, and six controls.",
    "- No parameter search, bootstrap inference, forward test, or edge promotion was opened.",
    "",
    "## Headline",
    "",
    sprintf(
      "The sector-ETF fleet produced %.2f%% CAGR versus %.2f%% for equal-weight sector ownership and %.2f%% for SPY, with %.2f%% maximum drawdown.",
      100 * etf$source_cagr, 100 * etf$equal_weight_cagr, 100 * etf$spy_cagr,
      100 * etf$source_max_drawdown
    ),
    sprintf(
      "Across the 11 stock-sector POCs, source dual momentum beat the sector's equal-weight basket on CAGR in %d/11 cases and had shallower drawdown in %d/11 cases.",
      sum(stock$source_beats_equal_cagr), sum(stock$source_drawdown_shallower_than_equal)
    ),
    sprintf(
      "The largest descriptive CAGR improvement over equal weight was %s (%+.2f percentage points); the weakest was %s (%+.2f points).",
      best$sector, 100 * best$source_minus_equal_cagr,
      worst$sector, 100 * worst$source_minus_equal_cagr
    ),
    sprintf(
      "The source rule stayed within 25 basis points of relative-only in %d/12 fleets; outside that band, the absolute gate was economically active rather than negligible.",
      sum(summary$source_within_25bp_of_relative)
    ),
    "",
    "## Interpretation boundary",
    "",
    "These POCs can reveal transport, heterogeneity, and possible universe dependence. They cannot show that a stock basket was tradeable ex ante because the stock atlas conditions on surviving long-history names. ETF evidence is cleaner, while stock evidence is a map for a later point-in-time universe test.",
    "",
    "## Artifacts",
    "",
    paste("- Summary:", basename(paths$summary)),
    paste("- Metrics:", basename(paths$metrics)),
    paste("- Weekly tape:", basename(paths$weekly_tape)),
    paste("- Universe registry:", basename(paths$universe_registry)),
    paste("- Visuals:", basename(dirname(paths$source_vs_equal_png))),
    "",
    "## Next decision",
    "",
    "First interpret whether behavior is broad, ETF-specific, or concentrated in a few stock sectors. Only then decide whether the next slice should reconstruct point-in-time memberships, test a broad stock fleet with breadth-preserving top-N, or freeze robustness perturbations."
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("LIT-MOM-03.2 universe-transport POCs starting.")
contract <- g5_mom032_contract()
universe_registry <- g5_mom032_universe_registry(repo_root, contract)
required_symbols <- g5_mom032_required_symbols(universe_registry, contract)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_03_2_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_03_2_REFRESH", FALSE)
run_id <- env_or(
  "GEN5_LIT_MOM_03_2_RUN_ID",
  "lit_mom_03_2_universe_transport_20260903"
)
output_dir <- file.path(repo_root, "runs", "research_workbench", "literature_grounded", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$signal_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = required_symbols,
  universe_name = "lit_mom_03_2_transport_assets",
  universe_roles = "frozen_transport_poc_assets",
  refresh = refresh,
  repo_root = repo_root
)
invisible(g5_write_workbench_query_artifacts(query, output_dir, "mom032_workbench_query"))
health_max <- health_maximum(query$health)
if (health_max %in% c("WARN", "ERROR")) {
  stop(paste("LIT-MOM-03.2 data admission stopped at", health_max), call. = FALSE)
}

result <- g5_mom032_run(query$bars, repo_root, contract)
summary <- result$summary
stock_summary <- summary[summary$universe_type == "STATIC_STOCK_SECTOR", , drop = FALSE]
etf_summary <- summary[summary$universe_type == "ETF_FLEET", , drop = FALSE]
run_spec <- data.frame(
  schema_version = g5_mom032_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_03_2_universe_transport.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  universes = nrow(summary),
  etf_fleets = sum(summary$universe_type == "ETF_FLEET"),
  static_stock_sector_fleets = sum(summary$universe_type == "STATIC_STOCK_SECTOR"),
  weekly_intervals_per_fleet = unique(result$metrics$intervals)[[1L]],
  stock_fleets_beating_equal_cagr = sum(stock_summary$source_beats_equal_cagr),
  stock_fleets_with_shallower_drawdown = sum(stock_summary$source_drawdown_shallower_than_equal),
  fleets_with_absolute_gate_within_25bp = sum(summary$source_within_25bp_of_relative),
  etf_source_cagr = etf_summary$source_cagr,
  etf_equal_weight_cagr = etf_summary$equal_weight_cagr,
  etf_spy_cagr = etf_summary$spy_cagr,
  inference_opened = contract$inference_opened,
  parameter_search_opened = contract$parameter_search_opened,
  forward_gate_opened = contract$forward_gate_opened,
  overall_status = "UNIVERSE_TRANSPORT_POC_COMPLETE_DESCRIPTIVE_ONLY",
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "mom032_run_spec.csv"),
  contract = file.path(output_dir, "mom032_contract.csv"),
  universe_registry = file.path(output_dir, "mom032_universe_registry.csv"),
  bar_coverage = file.path(output_dir, "mom032_bar_coverage.csv"),
  bar_integrity = file.path(output_dir, "mom032_bar_integrity.csv"),
  integrity = file.path(output_dir, "mom032_integrity.csv"),
  summary = file.path(output_dir, "mom032_transport_summary.csv"),
  metrics = file.path(output_dir, "mom032_portfolio_metrics.csv"),
  scores = file.path(output_dir, "mom032_score_tape.csv"),
  weekly_tape = file.path(output_dir, "mom032_weekly_portfolio_tape.csv"),
  source_vs_equal_png = file.path(visual_dir, "mom032_source_vs_equal_cagr.png"),
  drawdown_png = file.path(visual_dir, "mom032_source_vs_equal_drawdown.png"),
  component_png = file.path(visual_dir, "mom032_component_attribution.png"),
  scorecard_png = file.path(visual_dir, "mom032_transport_scorecard.png"),
  report = file.path(output_dir, "mom032_report.md")
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$contract)
write_csv(result$universe_registry, paths$universe_registry)
write_csv(result$bar_coverage, paths$bar_coverage)
write_csv(result$bar_integrity, paths$bar_integrity)
write_csv(result$integrity, paths$integrity)
write_csv(result$summary, paths$summary)
write_csv(result$metrics, paths$metrics)
write_csv(result$scores, paths$scores)
write_csv(result$weekly_tape, paths$weekly_tape)
render_source_vs_equal(result$summary, paths$source_vs_equal_png)
render_drawdown_control(result$summary, paths$drawdown_png)
render_component_attribution(result$summary, paths$component_png)
render_transport_scorecard(result$summary, paths$scorecard_png)
write_report(result, paths, run_spec)

message(paste("Run status:", run_spec$overall_status))
message(paste("Universes:", run_spec$universes))
message(paste("Weekly intervals per fleet:", run_spec$weekly_intervals_per_fleet))
message(paste("Stock fleets beating equal-weight CAGR:", run_spec$stock_fleets_beating_equal_cagr, "of 11"))
message(paste("Output:", normalizePath(output_dir, winslash = "/", mustWork = FALSE)))
