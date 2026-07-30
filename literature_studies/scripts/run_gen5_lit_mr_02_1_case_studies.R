# Build the retrospective 2018 case study and Chan source-period reproduction.

options(stringsAsFactors = FALSE)

repo_root <- normalizePath(".", winslash = "/", mustWork = TRUE)
local_library <- file.path(repo_root, ".codex_r_libs")
if (dir.exists(local_library)) {
  .libPaths(c(normalizePath(local_library, winslash = "/"), .libPaths()))
}
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mr_02_1_bollinger_poc.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mr_02_1_case_studies.R"))

args <- commandArgs(trailingOnly = TRUE)
refresh_reference <- !any(tolower(args) == "--refresh-reference=false")
canonical_run <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded",
  "lit_mr_02_1_bollinger_20260728"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded",
  "lit_mr_02_1_case_studies_20260729"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

read_required <- function(path) {
  if (!file.exists(path)) {
    g5_mr02_case_stop(paste("Required artifact is missing:", path))
  }
  utils::read.csv(path, stringsAsFactors = FALSE)
}

message("LIT-MR-02.1 case studies starting.")

canonical_indicators <- read_required(file.path(
  canonical_run, "mr02_train_indicators.csv"
))
canonical_replay <- read_required(file.path(
  canonical_run, "mr02_train_bar_replay.csv"
))
canonical_trades <- read_required(file.path(
  canonical_run, "mr02_train_trades.csv"
))
canonical_years <- read_required(file.path(
  canonical_run, "mr02_train_year_summary.csv"
))
canonical_indicators$session_date <- as.Date(canonical_indicators$session_date)
canonical_replay$signal_date <- as.Date(canonical_replay$signal_date)
canonical_replay$execution_date <- as.Date(canonical_replay$execution_date)
canonical_replay$next_execution_date <- as.Date(
  canonical_replay$next_execution_date
)
canonical_trades$entry_date <- as.Date(canonical_trades$entry_date)
canonical_trades$exit_date <- as.Date(canonical_trades$exit_date)

case_summary <- g5_mr02_case_2018_summary(
  canonical_replay, canonical_trades
)
utils::write.csv(
  case_summary, file.path(output_dir, "mr02_case_2018_summary.csv"),
  row.names = FALSE
)
case_trades <- canonical_trades[
  canonical_trades$completed &
    format(canonical_trades$exit_date, "%Y") == "2018",
  ,
  drop = FALSE
]
utils::write.csv(
  case_trades, file.path(output_dir, "mr02_case_2018_trades.csv"),
  row.names = FALSE
)

g5_mr02_plot_2018_anatomy(
  canonical_indicators, canonical_replay,
  file.path(visual_dir, "mr02_case_2018_strategy_anatomy.png")
)
g5_mr02_plot_2018_trades(
  canonical_trades,
  file.path(visual_dir, "mr02_case_2018_trade_timeline.png")
)
g5_mr02_plot_2018_trade_economics(
  canonical_trades,
  file.path(visual_dir, "mr02_case_2018_trade_economics.png")
)
g5_mr02_plot_year_context(
  canonical_years,
  file.path(visual_dir, "mr02_case_2018_five_year_context.png")
)

reference_contract <- g5_mr02_reference_contract()
reference_bars_path <- file.path(
  output_dir, "mr02_source_reference_yahoo_bars.csv"
)
if (refresh_reference || !file.exists(reference_bars_path)) {
  gld <- g5_mr02_fetch_yahoo_reference_bars(
    "GLD", reference_contract$query_start, reference_contract$query_end,
    reference_contract$as_of_timestamp
  )
  gld_url <- attr(gld, "source_url")
  uso <- g5_mr02_fetch_yahoo_reference_bars(
    "USO", reference_contract$query_start, reference_contract$query_end,
    reference_contract$as_of_timestamp
  )
  uso_url <- attr(uso, "source_url")
  reference_bars <- rbind(gld, uso)
  reference_bars <- reference_bars[
    order(reference_bars$session_date, reference_bars$symbol),
    ,
    drop = FALSE
  ]
  utils::write.csv(reference_bars, reference_bars_path, row.names = FALSE)
  source_urls <- data.frame(
    symbol = c("GLD", "USO"),
    url = c(gld_url, uso_url),
    retrieved_as_of = reference_contract$as_of_timestamp,
    provider_scope = "reference_only_not_canonical_gen5",
    stringsAsFactors = FALSE
  )
  utils::write.csv(
    source_urls, file.path(output_dir, "mr02_source_reference_urls.csv"),
    row.names = FALSE
  )
} else {
  reference_bars <- read_required(reference_bars_path)
  reference_bars$session_date <- as.Date(reference_bars$session_date)
}

reference_bars$session_date <- as.Date(reference_bars$session_date)
audit <- do.call(rbind, lapply(c("GLD", "USO"), function(symbol) {
  x <- reference_bars[reference_bars$symbol == symbol, , drop = FALSE]
  data.frame(
    symbol = symbol,
    rows = nrow(x),
    first_session = min(x$session_date),
    last_session = max(x$session_date),
    duplicate_sessions = sum(duplicated(x$session_date)),
    finite_adjusted_ohlc = all(is.finite(as.matrix(
      x[c("open", "high", "low", "close")]
    ))),
    status = if (
      nrow(x) >= 1400L &&
      min(x$session_date) <= reference_contract$query_start &&
      max(x$session_date) >= reference_contract$query_end &&
      !anyDuplicated(x$session_date)
    ) "PASS" else "FAIL",
    stringsAsFactors = FALSE
  )
}))
utils::write.csv(
  audit, file.path(output_dir, "mr02_source_reference_audit.csv"),
  row.names = FALSE
)
if (any(audit$status != "PASS")) {
  g5_mr02_case_stop("Yahoo reference coverage audit failed.")
}

panel <- g5_mr02_common_panel(reference_bars, reference_contract)
base_indicators <- g5_mr02_rolling_indicators(panel, reference_contract)
source_indicators <- g5_mr02_source_signal_states(
  base_indicators, reference_contract
)
source_replay <- g5_mr02_source_close_replay(source_indicators)
gen5_indicators <- g5_mr02_signal_states(base_indicators, reference_contract)
gen5_replay <- g5_mr02_build_replay(gen5_indicators, reference_contract)
gen5_trades <- g5_mr02_trade_summary(gen5_replay)

source_metrics <- g5_mr02_performance_metrics(
  source_replay$source_gross_return
)
source_metrics$accounting <- "book_style_close_to_close_no_cost"
gen5_metrics <- g5_mr02_performance_metrics(
  gen5_replay$primary_net_return
)
gen5_metrics$accounting <- "gen5_next_open_primary_cost"
comparison <- rbind(source_metrics, gen5_metrics)
comparison$published_apr <- 0.178
comparison$published_sharpe <- 0.96
comparison$reference_provider <- "Yahoo chart adjusted daily, reference only"
comparison$positive_beta_coverage <- mean(
  is.finite(base_indicators$beta) & base_indicators$beta > 0,
  na.rm = TRUE
)
comparison$completed_trades <- c(
  NA_integer_, sum(gen5_trades$completed)
)

utils::write.csv(
  source_indicators,
  file.path(output_dir, "mr02_source_period_indicators.csv"),
  row.names = FALSE
)
utils::write.csv(
  source_replay,
  file.path(output_dir, "mr02_source_period_book_style_replay.csv"),
  row.names = FALSE
)
utils::write.csv(
  gen5_replay,
  file.path(output_dir, "mr02_source_period_gen5_replay.csv"),
  row.names = FALSE
)
utils::write.csv(
  gen5_trades,
  file.path(output_dir, "mr02_source_period_gen5_trades.csv"),
  row.names = FALSE
)
utils::write.csv(
  comparison,
  file.path(output_dir, "mr02_source_period_comparison.csv"),
  row.names = FALSE
)

g5_mr02_plot_source_reproduction(
  source_replay, gen5_replay,
  file.path(visual_dir, "mr02_source_period_reproduction.png")
)
g5_mr02_plot_source_signal_tape(
  source_indicators,
  file.path(visual_dir, "mr02_source_period_signal_tape.png")
)

report <- c(
  "# LIT-MR-02.1 Positive-Control Case Studies",
  "",
  "## 2018 retrospective working regime",
  "",
  sprintf(
    "- Primary-cost return: `%+.2f%%`; naive Sharpe: `%.3f`; maximum drawdown: `%+.2f%%`.",
    100 * case_summary$cumulative_return,
    case_summary$naive_sharpe,
    100 * case_summary$maximum_drawdown
  ),
  sprintf(
    "- `%d` completed trades, `%d` wins (`%.1f%%`), with `%d` long-spread and `%d` short-spread trades.",
    case_summary$completed_trades, case_summary$wins,
    100 * case_summary$hit_rate,
    case_summary$long_trades, case_summary$short_trades
  ),
  "- This is an ex-post pedagogical case study. It does not alter the five-year STOP.",
  "",
  "## Chan source-period reproduction",
  "",
  sprintf(
    "- Yahoo reference coverage: `%s` common daily sessions from `%s` through `%s`.",
    nrow(panel), min(panel$session_date), max(panel$session_date)
  ),
  sprintf(
    "- Book-style close-to-close, cost-free reproduction: APR `%+.2f%%`, naive Sharpe `%.3f`, cumulative return `%+.2f%%`.",
    100 * source_metrics$apr, source_metrics$naive_sharpe,
    100 * source_metrics$cumulative_return
  ),
  sprintf(
    "- Gen5 next-open primary-cost translation: APR `%+.2f%%`, naive Sharpe `%.3f`, cumulative return `%+.2f%%`.",
    100 * gen5_metrics$apr, gen5_metrics$naive_sharpe,
    100 * gen5_metrics$cumulative_return
  ),
  "- Chan reports 17.8% APR and 0.96 Sharpe. Differences are interpreted as data-vintage and accounting evidence, not tuned away.",
  "- Yahoo data is quarantined reference evidence and does not change the canonical Alpaca provider contract.",
  "",
  "## Status",
  "",
  "`POSITIVE_CONTROL_DOCUMENTED_WITHOUT_REVERSING_STOP`"
)
writeLines(report, file.path(output_dir, "mr02_case_studies_report.md"))

message("2018 case summary: ", sprintf(
  "%+.2f%%, Sharpe %.3f, max DD %+.2f%%",
  100 * case_summary$cumulative_return,
  case_summary$naive_sharpe,
  100 * case_summary$maximum_drawdown
))
message("Source reproduction: ", sprintf(
  "book-style APR %+.2f%% / Sharpe %.3f; Gen5 APR %+.2f%% / Sharpe %.3f",
  100 * source_metrics$apr, source_metrics$naive_sharpe,
  100 * gen5_metrics$apr, gen5_metrics$naive_sharpe
))
message("Artifacts: ", output_dir)
