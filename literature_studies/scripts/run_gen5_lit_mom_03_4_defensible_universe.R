# Run the frozen LIT-MOM-03.4 ex-ante deployment-cohort replay.

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
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_03_2_universe_transport.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_03_4_defensible_universe.R"))
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
  if (!dir.exists(path)) stop("Could not create LIT-MOM-03.4 output directory.", call. = FALSE)
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
  ink = "#101820", blue = "#3D8DFF", light_blue = "#6DCBF4",
  green = "#2E7D5B", orange = "#C8553D", gray = "#8B95A1",
  grid = "#D9E2EA", pale = "#EEF3F7"
)

open_png <- function(path) {
  grDevices::png(path, width = 1800, height = 1050, res = 150, bg = "white")
  graphics::par(family = "sans", col.axis = theme$ink, col.lab = theme$ink)
}

variant_label <- function(x) {
  unname(c(
    SOURCE_DUAL_MOMENTUM = "Dual momentum",
    EQUAL_WEIGHT_UNIVERSE = "Equal-weight cohort",
    RELATIVE_ONLY = "Relative only",
    ABSOLUTE_ONLY = "Absolute only",
    SPY_OWNERSHIP = "SPY",
    CASH_NO_TRADE = "Cash"
  )[x])
}

render_breadth <- function(breadth, path, contract) {
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(
    breadth$decision_date, breadth$scoreable_count, type = "l", lwd = 3,
    col = theme$blue, ylim = c(0, contract$universe_size), xlab = "",
    ylab = "Causally scoreable stocks",
    main = "The ex-ante cohort remains broad as identities disappear",
    cex.main = 1.35, cex.lab = 1.05
  )
  graphics::grid(col = theme$grid)
  graphics::abline(
    h = contract$universe_size * c(
      contract$minimum_weekly_scoreable_fraction,
      contract$minimum_median_scoreable_fraction
    ),
    col = c(theme$orange, theme$gray), lty = c(2, 3), lwd = 2
  )
  graphics::legend(
    "bottomleft",
    legend = c("Scoreable breadth", "80% hard floor", "90% median gate"),
    col = c(theme$blue, theme$orange, theme$gray), lty = c(1, 2, 3),
    lwd = c(3, 2, 2), bty = "n"
  )
}

render_growth <- function(tape, path) {
  keep <- c("SOURCE_DUAL_MOMENTUM", "EQUAL_WEIGHT_UNIVERSE", "RELATIVE_ONLY", "SPY_OWNERSHIP")
  colors <- c(
    SOURCE_DUAL_MOMENTUM = theme$blue,
    EQUAL_WEIGHT_UNIVERSE = theme$gray,
    RELATIVE_ONLY = theme$green,
    SPY_OWNERSHIP = theme$orange
  )
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  values <- tape$wealth[tape$variant %in% keep]
  graphics::plot(
    range(tape$next_execution_date), range(c(1, values), finite = TRUE),
    type = "n", log = "y", xlab = "", ylab = "Growth of $1 (log scale)",
    main = "One ex-ante cohort: ranking versus ownership",
    cex.main = 1.35, cex.lab = 1.05
  )
  graphics::grid(col = theme$grid)
  for (variant in keep) {
    x <- tape[tape$variant == variant, , drop = FALSE]
    graphics::lines(x$next_execution_date, x$wealth, col = colors[[variant]], lwd = 3)
  }
  graphics::legend(
    "topleft", legend = variant_label(keep), col = unname(colors[keep]),
    lwd = 3, bty = "n", ncol = 2
  )
}

render_metrics <- function(metrics, path) {
  variants <- c(
    "SOURCE_DUAL_MOMENTUM", "RELATIVE_ONLY", "ABSOLUTE_ONLY",
    "EQUAL_WEIGHT_UNIVERSE", "SPY_OWNERSHIP", "CASH_NO_TRADE"
  )
  x <- metrics[match(variants, metrics$variant), , drop = FALSE]
  colors <- c(theme$blue, theme$green, theme$light_blue, theme$gray, theme$orange, theme$pale)
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(9, 5, 4, 1))
  graphics::barplot(
    100 * x$cagr_net, names.arg = variant_label(x$variant), las = 2,
    col = colors, border = NA, ylab = "Net CAGR (%)", main = "Return", cex.names = 0.78
  )
  graphics::abline(h = 0, col = theme$ink)
  graphics::barplot(
    100 * x$max_drawdown, names.arg = variant_label(x$variant), las = 2,
    col = colors, border = NA, ylab = "Maximum drawdown (%)", main = "Drawdown", cex.names = 0.78
  )
  graphics::abline(h = 0, col = theme$ink)
}

write_report <- function(result, run_spec, paths, raw_health_max) {
  admitted <- isTRUE(result$admission$admitted)
  breadth <- result$target_set$breadth
  lines <- c(
    "# LIT-MOM-03.4 defensible deployment-cohort replay",
    "",
    paste("Status:", run_spec$overall_status),
    "",
    "## Question",
    "",
    "Does the broad-fleet ranking clue survive when the stock cohort is fixed from public pre-evaluation evidence rather than selected from names known to survive through the endpoint?",
    "",
    "## Source and boundary",
    "",
    "- Source cohort: September 30, 2020 SPY holdings, SEC accession 0001752724-20-236128, accepted November 18, 2020.",
    "- Frozen eligible identities: 481 stocks with exact 2016-2020 adjusted-bar history, selected without post-2020 outcomes.",
    "- Evaluation begins January 2021. This is a fixed deployment cohort, not rolling S&P 500 membership.",
    "- Missing later identities remain visible. Failed next-open entries go to cash; held terminal events use the last observable adjusted close through the next rebalance.",
    "",
    "## Data admission",
    "",
    sprintf("Raw workbench health maximum: %s. Cache refresh was %s.", raw_health_max, run_spec$refresh),
    sprintf(
      "Scoreable breadth began at %d of 481, had a median of %.0f, and reached a minimum of %d.",
      breadth$scoreable_count[[1L]], stats::median(breadth$scoreable_count), min(breadth$scoreable_count)
    ),
    sprintf(
      "The largest terminal-proxy notional fraction across the four stock implementations was %.3f%%.",
      100 * result$admission$maximum_terminal_fraction
    ),
    paste("Admission gates:", paste(result$gates$status, collapse = ", ")),
    ""
  )
  if (admitted) {
    s <- result$summary[1L, ]
    lines <- c(lines,
      "## Descriptive outcome",
      "",
      sprintf(
        "Relative-only reached %.2f%% net CAGR versus %.2f%% for equal-weight ownership, a %+.2f-point ranking difference.",
        100 * s$relative_only_cagr, 100 * s$equal_weight_cagr, 100 * s$relative_minus_equal_cagr
      ),
      sprintf(
        "The full source rule reached %.2f%% CAGR and %.2f%% maximum drawdown; relative-only reached %.2f%% and %.2f%%.",
        100 * s$source_cagr, 100 * s$source_max_drawdown,
        100 * s$relative_only_cagr, 100 * s$relative_only_max_drawdown
      ),
      sprintf(
        "SPY reached %.2f%% CAGR with %.2f%% maximum drawdown in the same weekly window.",
        100 * s$spy_cagr, 100 * s$spy_max_drawdown
      ),
      "",
      "## Interpretation boundary",
      "",
      "This chronological source-cohort replay substantially repairs the static-survivor problem. It remains one source date and one later market period, with no inference, parameter perturbation, sealed confirmation period, leverage, or live authority.",
      ""
    )
  } else {
    failed <- result$gates$check_id[!result$gates$passed]
    lines <- c(lines,
      "## STOP",
      "",
      paste("Failed gates:", paste(failed, collapse = ", ")),
      "",
      "No performance metrics or economic interpretation were produced because the defensible-universe data contract did not admit the replay.",
      ""
    )
  }
  lines <- c(lines,
    "## Artifacts",
    "",
    paste("- Run spec:", basename(paths$run_spec)),
    paste("- Admission gates:", basename(paths$gates)),
    paste("- Breadth tape:", basename(paths$breadth)),
    paste("- Terminal events:", basename(paths$terminal_events)),
    if (admitted) paste("- Portfolio metrics:", basename(paths$metrics)) else NULL,
    "",
    "## Next decision",
    "",
    if (admitted) {
      "Decide whether the ranking difference warrants a small frozen robustness battery or should stop here. Do not tune the cash gate and ranking layer together."
    } else {
      "Repair only the failed data-integrity issue if an outcome-blind remedy exists; otherwise stop this stock-cohort translation."
    }
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("LIT-MOM-03.4 defensible deployment-cohort replay starting.")
contract <- g5_mom034_contract()
registry <- g5_mom034_registry(repo_root, contract)
required_symbols <- sort(unique(c(registry$symbol, contract$benchmark_symbol)))
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_03_4_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_03_4_REFRESH", FALSE)
run_id <- env_or("GEN5_LIT_MOM_03_4_RUN_ID", "lit_mom_03_4_defensible_universe_20260903")
output_dir <- file.path(repo_root, "runs", "research_workbench", "literature_grounded", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$signal_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = required_symbols,
  universe_name = "lit_mom_03_4_defensible_deployment_cohort",
  universe_roles = "frozen_2020_spy_deployment_cohort",
  refresh = refresh,
  repo_root = repo_root
)
invisible(g5_write_workbench_query_artifacts(query, output_dir, "mom034_workbench_query"))
raw_health_max <- g5_health_max_severity(query$health)

if (!refresh && any(query$refresh_plan$needs_fetch)) {
  stop(
    paste(
      "LIT-MOM-03.4 cache coverage requires refresh for",
      sum(query$refresh_plan$needs_fetch), "symbols; rerun with GEN5_LIT_MOM_03_4_REFRESH=true."
    ),
    call. = FALSE
  )
}

result <- g5_mom034_run(query$bars, repo_root, contract)
admitted <- isTRUE(result$admission$admitted)
status <- if (admitted) {
  "DEFENSIBLE_UNIVERSE_REPLAY_COMPLETE_DESCRIPTIVE_ONLY"
} else {
  "STOP_DEFENSIBLE_UNIVERSE_DATA_GATES_FAILED"
}

run_spec <- data.frame(
  schema_version = g5_mom034_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_03_4_defensible_universe.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  raw_data_health_max_severity = raw_health_max,
  frozen_assets = nrow(registry),
  sectors = length(unique(registry$sector)),
  first_signal_date = min(result$target_set$anchors$decision_date),
  final_signal_date = max(result$target_set$anchors$decision_date),
  weekly_intervals = nrow(result$intervals$metadata),
  admitted = admitted,
  overall_status = status,
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "mom034_run_spec.csv"),
  contract = file.path(output_dir, "mom034_contract.csv"),
  registry = file.path(output_dir, "mom034_frozen_registry.csv"),
  bar_integrity = file.path(output_dir, "mom034_bar_integrity.csv"),
  gates = file.path(output_dir, "mom034_admission_gates.csv"),
  breadth = file.path(output_dir, "mom034_scoreable_breadth.csv"),
  selection_check = file.path(output_dir, "mom034_selection_count_check.csv"),
  terminal_summary = file.path(output_dir, "mom034_terminal_proxy_summary.csv"),
  terminal_events = file.path(output_dir, "mom034_terminal_events.csv"),
  scores = file.path(output_dir, "mom034_score_tape.csv"),
  weekly_tape = file.path(output_dir, "mom034_weekly_portfolio_tape.csv"),
  metrics = file.path(output_dir, "mom034_portfolio_metrics.csv"),
  summary = file.path(output_dir, "mom034_summary.csv"),
  breadth_png = file.path(visual_dir, "mom034_scoreable_breadth.png"),
  growth_png = file.path(visual_dir, "mom034_growth_of_one.png"),
  metrics_png = file.path(visual_dir, "mom034_control_metrics.png"),
  report = file.path(output_dir, "mom034_report.md")
)

write_csv(run_spec, paths$run_spec)
write_csv(contract_table(contract), paths$contract)
write_csv(result$registry, paths$registry)
write_csv(result$bar_integrity, paths$bar_integrity)
write_csv(result$gates, paths$gates)
write_csv(result$target_set$breadth, paths$breadth)
write_csv(result$admission$selection_check, paths$selection_check)
write_csv(result$admission$terminal_summary, paths$terminal_summary)
write_csv(result$intervals$terminal_events, paths$terminal_events)
write_csv(result$target_set$scores, paths$scores)
render_breadth(result$target_set$breadth, paths$breadth_png, contract)

if (admitted) {
  write_csv(result$weekly_tape, paths$weekly_tape)
  write_csv(result$metrics, paths$metrics)
  write_csv(result$summary, paths$summary)
  render_growth(result$weekly_tape, paths$growth_png)
  render_metrics(result$metrics, paths$metrics_png)
}
write_report(result, run_spec, paths, raw_health_max)

message(paste("Run status:", status))
message(paste("Raw data health:", raw_health_max))
message(paste("Frozen assets:", nrow(registry)))
message(paste("Weekly intervals:", nrow(result$intervals$metadata)))
message(paste("Output:", normalizePath(output_dir, winslash = "/", mustWork = FALSE)))
