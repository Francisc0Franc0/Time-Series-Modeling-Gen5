# Run the frozen HYP-PORT-01.1 aggressive-compounding portfolio comparison.

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_port_01_1_aggressive_compounding.R"))
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
  if (!dir.exists(path)) stop("Could not create HYP-PORT-01.1 output directory.", call. = FALSE)
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

theme <- list(
  ink = "#12202F", navy = "#183B56", blue = "#2F80ED", cyan = "#56CCF2",
  green = "#27AE60", gold = "#F2C94C", orange = "#F2994A", red = "#EB5757",
  gray = "#8A96A3", pale = "#EDF2F7", grid = "#D8E1E8"
)

variant_label <- function(x) {
  unname(c(
    AGGRESSIVE_POLICY_BAND_REBALANCE = "Aggressive policy",
    AGGRESSIVE_POLICY_BUY_HOLD = "Same mix, no rebalance",
    EQUAL_WEIGHT_AMD_NVDA_TSLA = "AMD/NVDA/TSLA",
    SCHG_BUY_HOLD = "SCHG",
    QQQM_BUY_HOLD = "QQQM",
    SPY_DIAGNOSTIC = "SPY"
  )[x])
}

variant_colors <- c(
  AGGRESSIVE_POLICY_BAND_REBALANCE = theme$blue,
  AGGRESSIVE_POLICY_BUY_HOLD = theme$cyan,
  EQUAL_WEIGHT_AMD_NVDA_TSLA = theme$red,
  SCHG_BUY_HOLD = theme$green,
  QQQM_BUY_HOLD = theme$gold,
  SPY_DIAGNOSTIC = theme$gray
)

open_png <- function(path, width = 1800, height = 1050) {
  grDevices::png(path, width = width, height = height, res = 150, bg = "white")
  graphics::par(family = "sans", col.axis = theme$ink, col.lab = theme$ink)
}

render_growth <- function(tape, path, contract) {
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  y <- range(c(contract$initial_wealth, tape$wealth), finite = TRUE)
  graphics::plot(
    range(tape$next_execution_date), y, type = "n", log = "y", xlab = "",
    ylab = "Growth of $1 (log scale)", main = "Aggressive growth: concentration versus portfolio structure",
    cex.main = 1.32, cex.lab = 1.05
  )
  graphics::grid(col = theme$grid)
  for (variant in contract$variants) {
    x <- tape[tape$variant == variant, , drop = FALSE]
    graphics::lines(
      x$next_execution_date, x$wealth, col = variant_colors[[variant]],
      lwd = if (variant == "AGGRESSIVE_POLICY_BAND_REBALANCE") 4 else 2.4,
      lty = if (variant == "AGGRESSIVE_POLICY_BUY_HOLD") 2 else 1
    )
  }
  graphics::legend(
    "topleft", legend = variant_label(contract$variants),
    col = unname(variant_colors[contract$variants]),
    lwd = c(4, rep(2.4, 5)), lty = c(1, 2, 1, 1, 1, 1), bty = "n", ncol = 2
  )
}

render_drawdown <- function(tape, path, contract) {
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  y <- range(tape$drawdown, 0, finite = TRUE)
  graphics::plot(
    range(tape$next_execution_date), 100 * y, type = "n", xlab = "",
    ylab = "Drawdown from prior peak (%)", main = "The price paid for aggressive growth",
    cex.main = 1.32, cex.lab = 1.05
  )
  graphics::grid(col = theme$grid)
  for (variant in contract$variants) {
    x <- tape[tape$variant == variant, , drop = FALSE]
    graphics::lines(x$next_execution_date, 100 * x$drawdown, col = variant_colors[[variant]], lwd = 2.5)
  }
  graphics::abline(h = 0, col = theme$ink)
  graphics::legend(
    "bottomleft", legend = variant_label(contract$variants),
    col = unname(variant_colors[contract$variants]), lwd = 2.5, bty = "n", ncol = 2
  )
}

render_metrics <- function(metrics, path, contract) {
  x <- metrics[match(contract$variants, metrics$variant), , drop = FALSE]
  colors <- unname(variant_colors[x$variant])
  labels <- variant_label(x$variant)
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(9, 5, 4, 1))
  graphics::barplot(
    100 * x$cagr_net, names.arg = labels, las = 2, col = colors, border = NA,
    ylab = "Net CAGR (%)", main = "Annualized growth", cex.names = 0.78
  )
  graphics::abline(h = 0, col = theme$ink)
  graphics::barplot(
    100 * x$max_drawdown, names.arg = labels, las = 2, col = colors, border = NA,
    ylab = "Maximum drawdown (%)", main = "Worst peak-to-trough loss", cex.names = 0.78
  )
  graphics::abline(h = 0, col = theme$ink)
}

render_rolling <- function(rolling, path, contract) {
  x <- rolling[is.finite(rolling$rolling_three_year_annualized), , drop = FALSE]
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  y <- range(100 * x$rolling_three_year_annualized, 0, finite = TRUE)
  graphics::plot(
    range(x$session_date), y, type = "n", xlab = "",
    ylab = "Trailing 3-year annualized return (%)",
    main = "One endpoint is not enough: rolling three-year experience",
    cex.main = 1.32, cex.lab = 1.05
  )
  graphics::grid(col = theme$grid)
  for (variant in contract$variants) {
    z <- x[x$variant == variant, , drop = FALSE]
    graphics::lines(z$session_date, 100 * z$rolling_three_year_annualized,
      col = variant_colors[[variant]], lwd = 2.5)
  }
  graphics::abline(h = 0, col = theme$ink)
  graphics::legend(
    "topleft", legend = variant_label(contract$variants),
    col = unname(variant_colors[contract$variants]), lwd = 2.5, bty = "n", ncol = 2
  )
}

render_policy_weights <- function(tape, path, contract) {
  x <- tape[tape$variant == "AGGRESSIVE_POLICY_BAND_REBALANCE", , drop = FALSE]
  cols <- paste0("end_weight_", contract$policy_assets)
  mat <- as.matrix(x[, cols, drop = FALSE])
  palette <- c(theme$navy, theme$blue, theme$cyan, theme$gold, theme$orange, theme$red)
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::matplot(
    x$next_execution_date, 100 * mat, type = "l", lty = 1, lwd = 2.4,
    col = palette, xlab = "", ylab = "End-of-interval portfolio weight (%)",
    main = "Governance constrains drift; it does not remove concentration",
    cex.main = 1.32, cex.lab = 1.05
  )
  graphics::grid(col = theme$grid)
  graphics::legend("right", legend = contract$policy_assets, col = palette, lwd = 2.4, bty = "n")
}

render_calendar_heatmap <- function(calendar, path, contract) {
  years <- sort(unique(calendar$calendar_year))
  mat <- matrix(NA_real_, nrow = length(contract$variants), ncol = length(years),
    dimnames = list(variant_label(contract$variants), years))
  for (i in seq_len(nrow(calendar))) {
    mat[variant_label(calendar$variant[[i]]), as.character(calendar$calendar_year[[i]])] <-
      calendar$return[[i]]
  }
  limits <- max(abs(mat), na.rm = TRUE)
  breaks <- seq(-limits, limits, length.out = 101)
  colors <- grDevices::colorRampPalette(c(theme$red, "#FFFFFF", theme$green))(100)
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(5, 12, 4, 2))
  graphics::image(seq_along(years), seq_len(nrow(mat)), t(mat), col = colors, breaks = breaks,
    axes = FALSE, xlab = "Calendar year", ylab = "",
    main = "Calendar experience exposes path dependence", cex.main = 1.32)
  graphics::axis(1, at = seq_along(years), labels = years)
  graphics::axis(2, at = seq_len(nrow(mat)), labels = rownames(mat), las = 2)
  for (r in seq_len(nrow(mat))) for (c in seq_along(years)) {
    if (is.finite(mat[r, c])) graphics::text(c, r, sprintf("%+.0f%%", 100 * mat[r, c]), cex = 0.83)
  }
}

write_report <- function(result, run_spec, paths, raw_health_max) {
  admitted <- isTRUE(result$admitted)
  lines <- c(
    "# HYP-PORT-01.1 aggressive-compounding portfolio comparison",
    "",
    paste("Status:", run_spec$overall_status),
    "",
    "## Question",
    "",
    "Would a structured aggressive-growth portfolio have produced a more useful historical return/risk shape than concentrated AMD/NVDA/TSLA ownership, SCHG, or QQQM?",
    "",
    "## Frozen design",
    "",
    "- Policy: 50% SCHG, 20% QUAL, 15% XSD, and 5% each AMD/NVDA/TSLA.",
    "- Quarterly review with 20% relative drift bands; forced target restore each calendar year.",
    "- Same-mix buy-and-hold is the direct control for the rebalance rule.",
    "- Equal-weight AMD/NVDA/TSLA, SCHG, QQQM, and SPY are contextual comparators.",
    "- All variants share QQQM's actual common-history window; no QQQ proxy is used.",
    "- Open-to-open replay with 5 bps one-way cost on traded notional.",
    "",
    "## Admission",
    "",
    sprintf("Raw workbench health maximum: %s. Cache refresh was %s.", raw_health_max, run_spec$refresh),
    sprintf("Common panel retained %.2f%% of SPY sessions.", 100 * result$panel$common_session_fraction),
    paste("Admission gates:", paste(result$gates$status, collapse = ", ")),
    ""
  )
  if (admitted) {
    m <- result$metrics
    row <- function(variant) m[m$variant == variant, , drop = FALSE][1L, ]
    p <- row("AGGRESSIVE_POLICY_BAND_REBALANCE")
    bh <- row("AGGRESSIVE_POLICY_BUY_HOLD")
    trio <- row("EQUAL_WEIGHT_AMD_NVDA_TSLA")
    schg <- row("SCHG_BUY_HOLD")
    qqqm <- row("QQQM_BUY_HOLD")
    spy <- row("SPY_DIAGNOSTIC")
    lines <- c(lines,
      "## Descriptive result",
      "",
      sprintf("The policy reached %.2f%% net CAGR with %.2f%% maximum drawdown.", 100 * p$cagr_net, 100 * p$max_drawdown),
      sprintf("The same initial mix without rebalancing reached %.2f%% CAGR with %.2f%% maximum drawdown.", 100 * bh$cagr_net, 100 * bh$max_drawdown),
      sprintf("The concentrated trio reached %.2f%% CAGR with %.2f%% maximum drawdown.", 100 * trio$cagr_net, 100 * trio$max_drawdown),
      sprintf("SCHG, QQQM, and SPY reached %.2f%%, %.2f%%, and %.2f%% CAGR, respectively.", 100 * schg$cagr_net, 100 * qqqm$cagr_net, 100 * spy$cagr_net),
      sprintf("The policy generated %d allocation events and %.2fx one-way turnover including inception.", p$rebalance_events, p$total_turnover_one_way),
      "",
      "## Interpretation boundary",
      "",
      "This is a descriptive historical comparison over one short, hindsight-selected window. It can reveal trade-offs, but it cannot establish that the proposed weights are optimal, that historical outperformance will persist, or that this is a deployable strategy.",
      "",
      "Historical ETF look-through concentration, taxes, recurring contributions, parameter perturbation, walk-forward validation, and sealed confirmation are not tested.",
      ""
    )
  } else {
    lines <- c(lines,
      "## STOP",
      "",
      paste("Failed gates:", paste(result$gates$check_id[!result$gates$passed], collapse = ", ")),
      "",
      "No economic interpretation is admitted.",
      ""
    )
  }
  lines <- c(lines,
    "## Artifacts",
    "",
    paste("- Run spec:", basename(paths$run_spec)),
    paste("- Admission gates:", basename(paths$gates)),
    if (admitted) paste("- Metrics:", basename(paths$metrics)) else NULL,
    if (admitted) paste("- Rebalance tape:", basename(paths$rebalance_tape)) else NULL,
    "",
    "## Next decision",
    "",
    if (admitted) {
      "Decide whether this policy deserves a separately frozen robustness and contribution-policy study. Do not tune the weights or bands from this one outcome."
    } else {
      "Repair only an outcome-blind data issue if possible; otherwise stop this comparison."
    }
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("HYP-PORT-01.1 aggressive-compounding comparison starting.")
contract <- g5_port011_contract()
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_HYP_PORT_01_1_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_HYP_PORT_01_1_REFRESH", FALSE)
run_id <- env_or("GEN5_HYP_PORT_01_1_RUN_ID", "hyp_port_01_1_aggressive_compounding_20260903")
output_dir <- file.path(repo_root, "runs", "research_workbench", "operator_hypothesis_lab", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$evaluation_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = g5_port011_required_symbols(contract),
  universe_name = "hyp_port_01_1_aggressive_compounding",
  universe_roles = "policy_and_comparator_assets",
  refresh = refresh,
  repo_root = repo_root
)
invisible(g5_write_workbench_query_artifacts(query, output_dir, "port011_workbench_query"))
raw_health_max <- g5_health_max_severity(query$health)

if (!refresh && any(query$refresh_plan$needs_fetch)) {
  stop(
    paste(
      "HYP-PORT-01.1 cache coverage requires refresh for",
      sum(query$refresh_plan$needs_fetch), "symbols; rerun with GEN5_HYP_PORT_01_1_REFRESH=true."
    ),
    call. = FALSE
  )
}

result <- g5_port011_run(query$bars, contract)
admitted <- isTRUE(result$admitted)
status <- if (admitted) {
  "PORTFOLIO_POLICY_POC_COMPLETE_DESCRIPTIVE_ONLY"
} else {
  "STOP_PORTFOLIO_POLICY_DATA_GATES_FAILED"
}

run_spec <- data.frame(
  schema_version = g5_port011_schema_version(),
  wrapper = "operator_hypothesis_lab/scripts/run_hyp_port_01_1_aggressive_compounding.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  raw_data_health_max_severity = raw_health_max,
  common_sessions = length(result$panel$dates),
  common_session_fraction = result$panel$common_session_fraction,
  first_decision_date = result$panel$dates[[1L]],
  first_execution_date = result$panel$dates[[2L]],
  final_evaluation_date = tail(result$panel$dates, 1L),
  admitted = admitted,
  overall_status = status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "port011_run_spec.csv"),
  contract = file.path(output_dir, "port011_contract.csv"),
  coverage = file.path(output_dir, "port011_symbol_coverage.csv"),
  gates = file.path(output_dir, "port011_admission_gates.csv"),
  targets = file.path(output_dir, "port011_variant_targets.csv"),
  daily_tape = file.path(output_dir, "port011_daily_portfolio_tape.csv"),
  metrics = file.path(output_dir, "port011_portfolio_metrics.csv"),
  summary = file.path(output_dir, "port011_summary.csv"),
  calendar = file.path(output_dir, "port011_calendar_returns.csv"),
  rolling = file.path(output_dir, "port011_rolling_three_year.csv"),
  rebalance_tape = file.path(output_dir, "port011_rebalance_tape.csv"),
  growth_png = file.path(visual_dir, "port011_growth_of_one.png"),
  drawdown_png = file.path(visual_dir, "port011_drawdowns.png"),
  metrics_png = file.path(visual_dir, "port011_control_metrics.png"),
  rolling_png = file.path(visual_dir, "port011_rolling_three_year.png"),
  weights_png = file.path(visual_dir, "port011_policy_weights.png"),
  calendar_png = file.path(visual_dir, "port011_calendar_returns.png"),
  report = file.path(output_dir, "port011_report.md")
)

target_table <- do.call(rbind, lapply(names(result$targets), function(variant) {
  data.frame(variant = variant, asset = names(result$targets[[variant]]),
    target_weight = unname(result$targets[[variant]]), stringsAsFactors = FALSE)
}))
write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$contract)
write_csv(result$coverage, paths$coverage)
write_csv(result$gates, paths$gates)
write_csv(target_table, paths$targets)

if (admitted) {
  write_csv(result$daily_tape, paths$daily_tape)
  write_csv(result$metrics, paths$metrics)
  write_csv(result$summary, paths$summary)
  write_csv(result$calendar_returns, paths$calendar)
  write_csv(result$rolling_three_year, paths$rolling)
  write_csv(result$rebalance_tape, paths$rebalance_tape)
  render_growth(result$daily_tape, paths$growth_png, contract)
  render_drawdown(result$daily_tape, paths$drawdown_png, contract)
  render_metrics(result$metrics, paths$metrics_png, contract)
  render_rolling(result$rolling_three_year, paths$rolling_png, contract)
  render_policy_weights(result$daily_tape, paths$weights_png, contract)
  render_calendar_heatmap(result$calendar_returns, paths$calendar_png, contract)
}
write_report(result, run_spec, paths, raw_health_max)

message(paste("Run status:", status))
message(paste("Raw data health:", raw_health_max))
message(paste("Common sessions:", length(result$panel$dates)))
message(paste("Output:", normalizePath(output_dir, winslash = "/", mustWork = FALSE)))
