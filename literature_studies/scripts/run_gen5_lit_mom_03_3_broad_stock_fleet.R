# Run the frozen LIT-MOM-03.3 broad cross-sector stock-fleet POC.

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
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_03_3_broad_stock_fleet.R"))
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
  if (!dir.exists(path)) stop("Could not create LIT-MOM-03.3 output directory.", call. = FALSE)
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

theme_colors <- list(
  ink = "#101820", blue = "#3D8DFF", light_blue = "#6DCBF4",
  green = "#2E7D5B", orange = "#C8553D", gray = "#8B95A1",
  grid = "#D9E2EA", pale = "#EEF3F7"
)

open_png <- function(path) {
  grDevices::png(path, width = 1800, height = 1050, res = 150, bg = "white")
  graphics::par(family = "sans", col.axis = theme_colors$ink, col.lab = theme_colors$ink)
}

variant_label <- function(x) {
  unname(c(
    SOURCE_DUAL_MOMENTUM = "Dual momentum",
    EQUAL_WEIGHT_UNIVERSE = "Equal-weight 88",
    RELATIVE_ONLY = "Relative only",
    ABSOLUTE_ONLY = "Absolute only",
    SPY_OWNERSHIP = "SPY",
    CASH_NO_TRADE = "Cash"
  )[x])
}

render_growth <- function(tape, path) {
  keep <- c("SOURCE_DUAL_MOMENTUM", "EQUAL_WEIGHT_UNIVERSE", "RELATIVE_ONLY", "SPY_OWNERSHIP")
  colors <- c(
    SOURCE_DUAL_MOMENTUM = theme_colors$blue,
    EQUAL_WEIGHT_UNIVERSE = theme_colors$gray,
    RELATIVE_ONLY = theme_colors$green,
    SPY_OWNERSHIP = theme_colors$orange
  )
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  y <- tape$wealth[tape$variant %in% keep]
  graphics::plot(
    range(tape$next_execution_date), range(c(1, y), finite = TRUE), type = "n", log = "y",
    xlab = "", ylab = "Growth of $1 (log scale)",
    main = "One broad fleet: cross-sector substitution versus simpler ownership",
    cex.main = 1.35, cex.lab = 1.05
  )
  graphics::grid(col = theme_colors$grid)
  for (variant in keep) {
    x <- tape[tape$variant == variant, , drop = FALSE]
    graphics::lines(x$next_execution_date, x$wealth, col = colors[[variant]], lwd = 3)
  }
  graphics::legend(
    "topleft", legend = variant_label(keep), col = unname(colors[keep]),
    lwd = 3, bty = "n", ncol = 2
  )
}

render_control_metrics <- function(metrics, path) {
  order_variants <- c(
    "SOURCE_DUAL_MOMENTUM", "RELATIVE_ONLY", "ABSOLUTE_ONLY",
    "EQUAL_WEIGHT_UNIVERSE", "SPY_OWNERSHIP", "CASH_NO_TRADE"
  )
  x <- metrics[match(order_variants, metrics$variant), , drop = FALSE]
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mfrow = c(1, 2), mar = c(9, 5, 4, 1))
  colors <- c(theme_colors$blue, theme_colors$green, theme_colors$light_blue,
    theme_colors$gray, theme_colors$orange, theme_colors$pale)
  graphics::barplot(
    100 * x$cagr_net, names.arg = variant_label(x$variant), las = 2,
    col = colors, border = NA, ylab = "Net CAGR (%)",
    main = "Return", cex.names = 0.78
  )
  graphics::abline(h = 0, col = theme_colors$ink)
  graphics::barplot(
    100 * x$max_drawdown, names.arg = variant_label(x$variant), las = 2,
    col = colors, border = NA, ylab = "Maximum drawdown (%)",
    main = "Drawdown", cex.names = 0.78
  )
  graphics::abline(h = 0, col = theme_colors$ink)
}

render_sector_snapshots <- function(sector_tape, path) {
  dates <- sort(unique(sector_tape$decision_date))
  snapshot_index <- unique(round(seq(1, length(dates), length.out = 8)))
  snapshots <- dates[snapshot_index]
  x <- sector_tape[sector_tape$decision_date %in% snapshots, , drop = FALSE]
  matrix <- xtabs(source_target_weight ~ sector + decision_date, data = x)
  invested <- colSums(matrix)
  matrix <- rbind(matrix, Cash = pmax(0, 1 - invested))
  colors <- c(
    "#2B6CB0", "#4C9F70", "#D98E32", "#8C6BB1", "#CC6677", "#44AA99",
    "#999933", "#882255", "#117733", "#AA4499", "#6699CC", "#D9E2EA"
  )
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::par(mar = c(7, 5, 4, 13))
  graphics::barplot(
    matrix, col = colors[seq_len(nrow(matrix))], border = NA,
    names.arg = format(as.Date(colnames(matrix)), "%Y-%m-%d"), las = 2,
    ylab = "Target portfolio weight", ylim = c(0, 1),
    main = "Fixed-date snapshots show substitution across sectors"
  )
  graphics::legend(
    "right", inset = c(-0.29, 0), xpd = TRUE, legend = rownames(matrix),
    fill = colors[seq_len(nrow(matrix))], bty = "n", cex = 0.70
  )
}

render_exposure <- function(tape, path) {
  x <- tape[tape$variant == "SOURCE_DUAL_MOMENTUM", , drop = FALSE]
  open_png(path)
  on.exit(grDevices::dev.off(), add = TRUE)
  graphics::plot(
    x$decision_date, 100 * x$invested_target_weight, type = "l", lwd = 2.5,
    col = theme_colors$blue, ylim = c(0, 100), xlab = "",
    ylab = "Invested target weight (%)",
    main = "The absolute gate acts through time-varying cash exposure",
    cex.main = 1.35, cex.lab = 1.05
  )
  graphics::grid(col = theme_colors$grid)
  graphics::abline(h = mean(100 * x$invested_target_weight), col = theme_colors$orange, lty = 2, lwd = 2)
  graphics::legend(
    "bottomleft", legend = c("Weekly target", "Mean exposure"),
    col = c(theme_colors$blue, theme_colors$orange), lwd = 2.5, lty = c(1, 2), bty = "n"
  )
}

write_report <- function(result, paths, run_spec) {
  s <- result$summary[1L, ]
  lines <- c(
    "# LIT-MOM-03.3 broad cross-sector stock-fleet POC",
    "",
    paste("Status:", run_spec$overall_status),
    "",
    "## Question",
    "",
    "Does relative rotation look different when all 88 stocks compete together, allowing substitution across sectors rather than forcing a separate contest inside every sector?",
    "",
    "## Frozen design",
    "",
    "- One static 88-stock fleet: eight names in each of 11 sectors from the pre-existing long-history atlas.",
    "- The original three-of-nine selection fraction is preserved as 29-of-88 per 10-week and 25-week sleeve; top-N was not searched.",
    "- Wednesday-close signals, next-common-open execution, 5 bps one-way costs, alphabetical tie breaks, and the same six variants are unchanged.",
    "- The static fleet is survivor-biased and exploratory. No inference, parameter search, robustness test, forward gate, or edge promotion is opened.",
    "",
    "## Headline",
    "",
    sprintf(
      "Dual momentum produced %.2f%% net CAGR and %.2f%% maximum drawdown, versus %.2f%% and %.2f%% for equal-weight ownership of all 88 stocks.",
      100 * s$source_cagr, 100 * s$source_max_drawdown,
      100 * s$equal_weight_cagr, 100 * s$equal_weight_max_drawdown
    ),
    sprintf(
      "Relative-only produced %.2f%% CAGR. Its %+.2f-point difference versus equal weight isolates whether ranking itself added value before the absolute gate.",
      100 * s$relative_only_cagr, 100 * s$relative_minus_equal_cagr
    ),
    sprintf(
      "The positive-only gate changed CAGR by %+.2f points versus relative-only and changed maximum drawdown by %+.2f points; mean invested exposure was %.1f%%.",
      100 * s$source_minus_relative_cagr,
      100 * s$source_drawdown_improvement_vs_relative,
      100 * s$source_mean_invested_weight
    ),
    sprintf(
      "SPY produced %.2f%% CAGR and %.2f%% maximum drawdown over the same causal weekly intervals.",
      100 * s$spy_cagr, 100 * s$spy_max_drawdown
    ),
    "",
    "## Interpretation boundary",
    "",
    "This is a breadth and competition-structure POC. It can show whether cross-sector substitution changes the retrospective shape, but it cannot establish ex-ante tradeability because the 88-stock atlas conditions on surviving long-history names.",
    "",
    "## Artifacts",
    "",
    paste("- Summary:", basename(paths$summary)),
    paste("- Metrics:", basename(paths$metrics)),
    paste("- Weekly tape:", basename(paths$weekly_tape)),
    paste("- Sector allocation tape:", basename(paths$sector_tape)),
    paste("- Visuals:", basename(dirname(paths$growth_png))),
    "",
    "## Next decision",
    "",
    "Interpret whether cross-sector competition materially improved ranking value. Only then decide whether the next gate should reconstruct a point-in-time stock universe, freeze small robustness perturbations, or stop this transport lane."
  )
  writeLines(lines, paths$report, useBytes = TRUE)
}

message("LIT-MOM-03.3 broad stock-fleet POC starting.")
contract <- g5_mom033_contract()
universe_registry <- g5_mom033_universe_registry(repo_root, contract)
required_symbols <- g5_mom033_required_symbols(universe_registry, contract)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_03_3_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_03_3_REFRESH", FALSE)
run_id <- env_or("GEN5_LIT_MOM_03_3_RUN_ID", "lit_mom_03_3_broad_stock_fleet_20260903")
output_dir <- file.path(repo_root, "runs", "research_workbench", "literature_grounded", run_id)
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(visual_dir)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = contract$query_start,
  end_date = contract$signal_end,
  as_of_timestamp = contract$as_of_timestamp,
  symbols = required_symbols,
  universe_name = "lit_mom_03_3_broad_stock_fleet",
  universe_roles = "frozen_broad_cross_sector_poc_assets",
  refresh = refresh,
  repo_root = repo_root
)
invisible(g5_write_workbench_query_artifacts(query, output_dir, "mom033_workbench_query"))
health_max <- health_maximum(query$health)
if (health_max %in% c("WARN", "ERROR")) {
  stop(paste("LIT-MOM-03.3 data admission stopped at", health_max), call. = FALSE)
}

result <- g5_mom033_run(query$bars, repo_root, contract)
s <- result$summary[1L, ]
run_spec <- data.frame(
  schema_version = g5_mom033_schema_version(),
  wrapper = "literature_studies/scripts/run_gen5_lit_mom_03_3_broad_stock_fleet.R",
  run_id = run_id,
  as_of_timestamp = contract$as_of_timestamp,
  feed = cfg$feed,
  refresh = refresh,
  data_health_max_severity = health_max,
  universe_assets = nrow(result$universe_registry),
  sectors = length(unique(result$universe_registry$sector)),
  top_n_per_sleeve = contract$top_n_per_sleeve,
  weekly_intervals = unique(result$metrics$intervals)[[1L]],
  source_cagr = s$source_cagr,
  equal_weight_cagr = s$equal_weight_cagr,
  relative_only_cagr = s$relative_only_cagr,
  spy_cagr = s$spy_cagr,
  source_max_drawdown = s$source_max_drawdown,
  equal_weight_max_drawdown = s$equal_weight_max_drawdown,
  source_mean_invested_weight = s$source_mean_invested_weight,
  inference_opened = contract$inference_opened,
  parameter_search_opened = contract$parameter_search_opened,
  forward_gate_opened = contract$forward_gate_opened,
  overall_status = "BROAD_CROSS_SECTOR_STOCK_FLEET_POC_COMPLETE_DESCRIPTIVE_ONLY",
  output_dir = normalizePath(output_dir, winslash = "/", mustWork = FALSE),
  stringsAsFactors = FALSE
)

paths <- list(
  run_spec = file.path(output_dir, "mom033_run_spec.csv"),
  contract = file.path(output_dir, "mom033_contract.csv"),
  universe_registry = file.path(output_dir, "mom033_universe_registry.csv"),
  bar_coverage = file.path(output_dir, "mom033_bar_coverage.csv"),
  bar_integrity = file.path(output_dir, "mom033_bar_integrity.csv"),
  integrity = file.path(output_dir, "mom033_integrity.csv"),
  summary = file.path(output_dir, "mom033_broad_fleet_summary.csv"),
  metrics = file.path(output_dir, "mom033_portfolio_metrics.csv"),
  scores = file.path(output_dir, "mom033_score_tape.csv"),
  weekly_tape = file.path(output_dir, "mom033_weekly_portfolio_tape.csv"),
  sector_tape = file.path(output_dir, "mom033_sector_allocation_tape.csv"),
  growth_png = file.path(visual_dir, "mom033_growth_of_one.png"),
  metrics_png = file.path(visual_dir, "mom033_control_metrics.png"),
  sectors_png = file.path(visual_dir, "mom033_sector_allocation_snapshots.png"),
  exposure_png = file.path(visual_dir, "mom033_source_exposure.png"),
  report = file.path(output_dir, "mom033_report.md")
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
write_csv(result$sector_tape, paths$sector_tape)
render_growth(result$weekly_tape, paths$growth_png)
render_control_metrics(result$metrics, paths$metrics_png)
render_sector_snapshots(result$sector_tape, paths$sectors_png)
render_exposure(result$weekly_tape, paths$exposure_png)
write_report(result, paths, run_spec)

message(paste("Run status:", run_spec$overall_status))
message(paste("Assets / sectors:", run_spec$universe_assets, "/", run_spec$sectors))
message(paste("Top-N per sleeve:", run_spec$top_n_per_sleeve))
message(paste("Weekly intervals:", run_spec$weekly_intervals))
message(paste("Output:", normalizePath(output_dir, winslash = "/", mustWork = FALSE)))
