# Run LIT-MOM-01.2 / AUDIT_01_EXPOSURE_AND_SELECTION.

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
source(file.path(
  repo_root, "literature_studies", "R",
  "gen5_lit_mom_01_2_audit_01_exposure_selection.R"
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
}
bind_rows <- function(rows) {
  if (!length(rows)) return(data.frame())
  columns <- unique(unlist(lapply(rows, names), use.names = FALSE))
  normalized <- lapply(rows, function(x) {
    missing <- setdiff(columns, names(x))
    for (column in missing) x[[column]] <- NA
    x[columns]
  })
  do.call(rbind, normalized)
}
percent <- function(x, digits = 1L) {
  ifelse(is.finite(x), paste0(formatC(100 * x, digits = digits, format = "f"), "%"), "NA")
}

message("LIT-MOM-01.2 AUDIT_01 starting.")
audit_contract <- g5_mom012a_validate_contract(g5_mom012a_contract())
mom_contract <- g5_mom012_contract()
sector_etfs <- g5_mom012a_sector_etfs()

atlas01_root <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded",
  "lit_mom_01_2_long_only_stock_atlas_01_retrospective_20260802"
)
atlas02_root <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded",
  "lit_mom_01_2_long_only_stock_atlas_02_2020_breadth_attention_20260802"
)
shy_root <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded",
  "lit_mom_01_2_long_only_single_position_retrospective_20260802"
)
required_roots <- c(atlas01_root, atlas02_root, shy_root)
if (!all(dir.exists(required_roots))) {
  stop("Required corrected LIT-MOM-01.2 evidence packets are missing.", call. = FALSE)
}

shy_selected <- utils::read.csv(
  file.path(shy_root, "lit_mom_01_2_selected_candidate.csv"),
  stringsAsFactors = FALSE
)
shy_selected <- data.frame(
  instance_id = "SHY_TUTORIAL",
  symbol = "SHY",
  cohort = "SHY_TUTORIAL",
  sector = "Treasury",
  lookback_sessions = as.integer(shy_selected$lookback_sessions[[1L]]),
  holding_sessions = as.integer(shy_selected$holding_sessions[[1L]]),
  source_batch = "SHY_60_5_RETROSPECTIVE",
  stringsAsFactors = FALSE
)

atlas01_selected <- utils::read.csv(
  file.path(atlas01_root, "stock_atlas_01_selected_horizons.csv"),
  stringsAsFactors = FALSE
)
atlas01_selected$cohort <- "ATLAS_01_SECTOR_BALANCED"
atlas01_selected$source_batch <- "STOCK_ATLAS_01_RETROSPECTIVE"
atlas01_selected <- atlas01_selected[c(
  "instance_id", "symbol", "cohort", "sector", "lookback_sessions",
  "holding_sessions", "source_batch"
)]

atlas02_selected <- utils::read.csv(
  file.path(atlas02_root, "stock_atlas_02_selected_horizons.csv"),
  stringsAsFactors = FALSE
)
atlas02_selected$source_batch <- "STOCK_ATLAS_02_2020_BREADTH_ATTENTION"
atlas02_selected <- atlas02_selected[c(
  "instance_id", "symbol", "cohort", "sector", "lookback_sessions",
  "holding_sessions", "source_batch"
)]

universe <- rbind(shy_selected, atlas01_selected, atlas02_selected)
universe$lookback_sessions <- as.integer(universe$lookback_sessions)
universe$holding_sessions <- as.integer(universe$holding_sessions)
if (anyDuplicated(universe$symbol)) stop("Audit universe contains duplicate symbols.", call. = FALSE)

shy_metrics <- utils::read.csv(
  file.path(shy_root, "retrospective_performance_metrics.csv"),
  stringsAsFactors = FALSE
)
shy_metrics$instance_id <- "SHY_TUTORIAL"
shy_metrics$symbol <- "SHY"
shy_metrics$cohort <- "SHY_TUTORIAL"
shy_metrics$sector <- "Treasury"
shy_trades <- utils::read.csv(
  file.path(shy_root, "retrospective_trades.csv"),
  stringsAsFactors = FALSE
)
shy_trades$instance_id <- "SHY_TUTORIAL"
shy_trades$symbol <- "SHY"
shy_trades$cohort <- "SHY_TUTORIAL"
shy_trades$sector <- "Treasury"
shy_replay <- utils::read.csv(
  file.path(shy_root, "retrospective_bar_replay.csv"),
  stringsAsFactors = FALSE
)
shy_replay$instance_id <- "SHY_TUTORIAL"
shy_replay$symbol <- "SHY"
shy_replay$cohort <- "SHY_TUTORIAL"
shy_replay$sector <- "Treasury"

atlas01_metrics <- utils::read.csv(
  file.path(atlas01_root, "stock_atlas_01_retrospective_metrics.csv"),
  stringsAsFactors = FALSE
)
atlas01_metrics$cohort <- "ATLAS_01_SECTOR_BALANCED"
atlas01_trades <- utils::read.csv(
  file.path(atlas01_root, "stock_atlas_01_retrospective_trades.csv"),
  stringsAsFactors = FALSE
)
atlas01_trades$cohort <- "ATLAS_01_SECTOR_BALANCED"
atlas01_replay <- utils::read.csv(
  file.path(atlas01_root, "stock_atlas_01_retrospective_bar_replay.csv"),
  stringsAsFactors = FALSE
)
atlas01_replay$cohort <- "ATLAS_01_SECTOR_BALANCED"

atlas02_metrics <- utils::read.csv(
  file.path(atlas02_root, "stock_atlas_02_retrospective_metrics.csv"),
  stringsAsFactors = FALSE
)
atlas02_trades <- utils::read.csv(
  file.path(atlas02_root, "stock_atlas_02_retrospective_trades.csv"),
  stringsAsFactors = FALSE
)
atlas02_replay <- utils::read.csv(
  file.path(atlas02_root, "stock_atlas_02_retrospective_bar_replay.csv"),
  stringsAsFactors = FALSE
)

selected_metrics_all <- bind_rows(list(shy_metrics, atlas01_metrics, atlas02_metrics))
selected_trades_all <- bind_rows(list(shy_trades, atlas01_trades, atlas02_trades))
selected_replay_all <- bind_rows(list(shy_replay, atlas01_replay, atlas02_replay))
selected_trades_all$signal_date <- as.Date(selected_trades_all$signal_date)
selected_trades_all$entry_date <- as.Date(selected_trades_all$entry_date)
selected_trades_all$exit_date <- as.Date(selected_trades_all$exit_date)
selected_replay_all$outcome_date <- as.Date(selected_replay_all$outcome_date)
selected_replay_all$interval_entry_date <- as.Date(selected_replay_all$interval_entry_date)

run_id <- env_or(
  "GEN5_LIT_MOM_012_AUDIT01_RUN_ID",
  "lit_mom_01_2_audit_01_exposure_selection_20260802"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "literature_grounded", run_id
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_LIT_MOM_012_AUDIT01_FEED", as.character(cfg$feed))
refresh <- env_bool("GEN5_LIT_MOM_012_AUDIT01_REFRESH", FALSE)
reference_symbols <- unique(c("SPY", unname(sector_etfs)))
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = audit_contract$query_start,
  end_date = audit_contract$retrospective_end,
  as_of_timestamp = audit_contract$as_of_timestamp,
  symbols = unique(c(universe$symbol, reference_symbols)),
  universe_name = "lit_mom_01_2_audit_01_assets_and_references",
  universe_roles = "frozen_lit_mom_01_2_assets,reference_only",
  refresh = refresh,
  repo_root = repo_root
)
bars_all <- g5_mom012a_validate_bars(query$bars)
if (any(bars_all$session_date >= audit_contract$confirmation_start)) {
  stop("Confirmation bars entered AUDIT_01.", call. = FALSE)
}

coverage_rows <- lapply(unique(c(universe$symbol, reference_symbols)), function(symbol) {
  dates <- bars_all$session_date[bars_all$symbol == symbol]
  data.frame(
    symbol = symbol,
    first_session = if (length(dates)) min(dates) else as.Date(NA),
    last_session = if (length(dates)) max(dates) else as.Date(NA),
    retrospective_start_covered = length(dates) && min(dates) <= audit_contract$retrospective_start,
    retrospective_end_covered = length(dates) && max(dates) >= audit_contract$retrospective_end,
    confirmation_excluded = !length(dates) || max(dates) < audit_contract$confirmation_start,
    stringsAsFactors = FALSE
  )
})
coverage <- do.call(rbind, coverage_rows)
asset_coverage <- coverage[coverage$symbol %in% universe$symbol, , drop = FALSE]
if (!all(asset_coverage$retrospective_start_covered &
         asset_coverage$retrospective_end_covered &
         asset_coverage$confirmation_excluded)) {
  stop("An audit asset lacks the frozen retrospective boundary.", call. = FALSE)
}
reference_coverage <- coverage[coverage$symbol %in% reference_symbols, , drop = FALSE]
if (!all(reference_coverage$retrospective_start_covered &
         reference_coverage$retrospective_end_covered)) {
  stop("A market or sector reference lacks the retrospective boundary.", call. = FALSE)
}

spy_bars <- bars_all[bars_all$symbol == "SPY", , drop = FALSE]
spy_bars <- spy_bars[order(spy_bars$session_date), , drop = FALSE]
spy_returns <- data.frame(
  outcome_date = spy_bars$session_date[-1L],
  spy_return = spy_bars$open[-1L] / head(spy_bars$open, -1L) - 1,
  stringsAsFactors = FALSE
)
spy_features <- g5_mom012a_feature_panel(
  spy_bars,
  audit_contract$market_trend_sessions,
  audit_contract$volatility_sessions
)
train_vol_threshold <- stats::median(
  spy_features$realized_volatility[
    spy_features$signal_date >= audit_contract$train_start &
      spy_features$signal_date <= audit_contract$train_end
  ],
  na.rm = TRUE
)

sector_features <- lapply(unname(sector_etfs), function(symbol) {
  x <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  panel <- g5_mom012a_feature_panel(
    x,
    audit_contract$market_trend_sessions,
    audit_contract$volatility_sessions
  )
  panel$sector_etf <- symbol
  panel
})
names(sector_features) <- unname(sector_etfs)

fixed_rule_return <- function(bars, lookback, holding, contract) {
  schedule <- g5_mom012_trade_schedule(
    bars,
    audit_contract$retrospective_start,
    audit_contract$retrospective_end,
    as.integer(lookback),
    as.integer(holding),
    contract
  )
  g5_mom012a_schedule_return(
    bars,
    schedule$entry_index,
    as.integer(holding),
    audit_contract$primary_cost_bps
  )
}

buy_hold_direct <- function(bars) {
  schedule <- g5_mom012a_buy_hold_schedule(
    bars, audit_contract$retrospective_start, audit_contract$retrospective_end
  )
  entry <- schedule$entry_index[[1L]]
  exit <- schedule$exit_index[[1L]]
  cost_rate <- audit_contract$primary_cost_bps / 10000
  units <- (1 / (1 + cost_rate)) / bars$open[[entry]]
  wealth <- units * bars$open[(entry + 1L):exit]
  wealth[[length(wealth)]] <- wealth[[length(wealth)]] * (1 - cost_rate)
  peak <- cummax(c(1, wealth))[-1L]
  data.frame(
    cumulative_return = tail(wealth, 1L) - 1,
    maximum_drawdown = min(wealth / peak - 1),
    stringsAsFactors = FALSE
  )
}

asset_rows <- list()
trade_rows <- list()
daily_rows <- list()
integrity_rows <- list()

for (i in seq_len(nrow(universe))) {
  row <- universe[i, , drop = FALSE]
  symbol <- row$symbol[[1L]]
  message(sprintf("AUDIT_01 asset %03d/%03d: %s", i, nrow(universe), symbol))
  bars <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  bars <- bars[order(bars$session_date), , drop = FALSE]
  asset_contract <- if (symbol == "SHY") {
    g5_mom012_contract()
  } else {
    batch <- if (row$source_batch[[1L]] == "STOCK_ATLAS_02_2020_BREADTH_ATTENTION") {
      "STOCK_ATLAS_02_2020_BREADTH_ATTENTION"
    } else {
      "STOCK_ATLAS_01_RETROSPECTIVE"
    }
    g5_mom012_replication_contract(symbol, batch)
  }

  selected_metric <- selected_metrics_all[
    selected_metrics_all$symbol == symbol &
      selected_metrics_all$regime_id == "PRIMARY", , drop = FALSE
  ]
  selected_trade <- selected_trades_all[
    selected_trades_all$symbol == symbol &
      selected_trades_all$regime_id == "PRIMARY", , drop = FALSE
  ]
  selected_replay <- selected_replay_all[
    selected_replay_all$symbol == symbol &
      selected_replay_all$regime_id == "PRIMARY", , drop = FALSE
  ]
  if (nrow(selected_metric) != 1L || !nrow(selected_trade) || !nrow(selected_replay)) {
    stop(paste("Frozen selected evidence is incomplete for", symbol), call. = FALSE)
  }
  selected_return <- selected_metric$cumulative_return[[1L]]
  selected_mdd <- selected_metric$maximum_drawdown[[1L]]
  daily <- g5_mom012a_complete_daily_path(
    bars, selected_replay,
    audit_contract$retrospective_start,
    audit_contract$retrospective_end
  )
  participation <- nrow(selected_replay) / nrow(daily)

  buy_metrics <- buy_hold_direct(bars)

  always_schedule <- g5_mom012a_always_long_schedule(
    bars, audit_contract$retrospective_start, audit_contract$retrospective_end,
    row$holding_sessions[[1L]]
  )
  always_return <- g5_mom012a_schedule_return(
    bars,
    always_schedule$entry_index,
    row$holding_sessions[[1L]],
    audit_contract$primary_cost_bps
  )

  constant_metrics <- g5_mom012a_constant_exposure(
    daily, participation, audit_contract$primary_cost_bps
  )
  fixed_250_25_return <- fixed_rule_return(bars, 250L, 25L, asset_contract)
  fixed_60_5_return <- fixed_rule_return(bars, 60L, 5L, asset_contract)
  random <- g5_mom012a_random_timing(
    bars,
    audit_contract$retrospective_start,
    audit_contract$retrospective_end,
    row$holding_sessions[[1L]],
    nrow(selected_trade),
    selected_return,
    audit_contract$random_schedule_count,
    audit_contract$random_seed + i,
    audit_contract$primary_cost_bps
  )
  regression <- g5_mom012a_regression(daily, spy_returns)

  asset_rows[[i]] <- cbind(
    row,
    data.frame(
      selected_return = selected_return,
      selected_maximum_drawdown = selected_mdd,
      selected_trade_count = nrow(selected_trade),
      selected_long_call_accuracy = mean(selected_trade$direction_correct),
      calendar_participation = participation,
      buy_hold_return = buy_metrics$cumulative_return[[1L]],
      buy_hold_maximum_drawdown = buy_metrics$maximum_drawdown[[1L]],
      constant_exposure_return = constant_metrics[["cumulative_return"]],
      constant_exposure_maximum_drawdown = constant_metrics[["maximum_drawdown"]],
      always_long_block_return = always_return,
      fixed_250_25_return = fixed_250_25_return,
      fixed_60_5_return = fixed_60_5_return,
      excess_vs_buy_hold = selected_return - buy_metrics$cumulative_return[[1L]],
      excess_vs_constant_exposure = selected_return - constant_metrics[["cumulative_return"]],
      excess_vs_always_long_block = selected_return - always_return,
      selected_minus_fixed_250_25 = selected_return - fixed_250_25_return,
      selected_minus_fixed_60_5 = selected_return - fixed_60_5_return,
      stringsAsFactors = FALSE
    ),
    random,
    regression
  )

  primary_trades <- selected_trade
  primary_trades$instance_id <- row$instance_id[[1L]]
  primary_trades$symbol <- symbol
  primary_trades$cohort <- row$cohort[[1L]]
  primary_trades$sector <- row$sector[[1L]]
  primary_trades$lookback_sessions <- row$lookback_sessions[[1L]]
  primary_trades$holding_sessions <- row$holding_sessions[[1L]]
  trade_rows[[i]] <- primary_trades

  daily$instance_id <- row$instance_id[[1L]]
  daily$symbol <- symbol
  daily$cohort <- row$cohort[[1L]]
  daily$sector <- row$sector[[1L]]
  daily_rows[[i]] <- daily

  integrity_rows[[i]] <- data.frame(
    instance_id = row$instance_id[[1L]],
    symbol = symbol,
    long_only = all(selected_trade$direction == 1L),
    zero_borrow = sum(selected_replay$borrow_cost) == 0,
    schedule_nonoverlap = nrow(selected_trade) < 2L ||
      all(selected_trade$entry_index[-1L] >= head(selected_trade$exit_index, -1L)),
    selected_horizon_preserved = all(
      selected_trade$exit_index - selected_trade$entry_index == row$holding_sessions[[1L]]
    ),
    confirmation_excluded = max(bars$session_date) < audit_contract$confirmation_start,
    random_schedule_count_exact =
      random$random_simulation_count == audit_contract$random_schedule_count,
    stringsAsFactors = FALSE
  )
}

asset_summary <- bind_rows(asset_rows)
selected_trades <- bind_rows(trade_rows)
daily_paths <- bind_rows(daily_rows)
integrity <- bind_rows(integrity_rows)
integrity$all_checks_pass <- apply(integrity[setdiff(names(integrity), c("instance_id", "symbol"))], 1, all)

# Attach the four frozen causal environment descriptors.
asset_features <- lapply(unique(universe$symbol), function(symbol) {
  x <- bars_all[bars_all$symbol == symbol, , drop = FALSE]
  g5_mom012a_feature_panel(
    x,
    audit_contract$market_trend_sessions,
    audit_contract$volatility_sessions
  )
})
names(asset_features) <- unique(universe$symbol)
environment_rows <- vector("list", nrow(selected_trades))
for (i in seq_len(nrow(selected_trades))) {
  trade <- selected_trades[i, , drop = FALSE]
  signal_date <- as.Date(trade$signal_date[[1L]])
  spy_i <- match(signal_date, spy_features$signal_date)
  asset_feature <- asset_features[[trade$symbol[[1L]]]]
  asset_i <- match(signal_date, asset_feature$signal_date)
  sector_symbol <- unname(sector_etfs[trade$sector[[1L]]])
  sector_return <- NA_real_
  if (length(sector_symbol) && !is.na(sector_symbol) && sector_symbol %in% names(sector_features)) {
    sector_panel <- sector_features[[sector_symbol]]
    sector_i <- match(signal_date, sector_panel$signal_date)
    sector_return <- sector_panel$trailing_return[[sector_i]]
  }
  market_return <- spy_features$trailing_return[[spy_i]]
  market_vol <- spy_features$realized_volatility[[spy_i]]
  asset_return <- asset_feature$trailing_return[[asset_i]]
  environment_rows[[i]] <- cbind(
    trade,
    data.frame(
      market_trailing_return = market_return,
      market_realized_volatility = market_vol,
      sector_trailing_return = sector_return,
      asset_trailing_return = asset_return,
      market_trend = ifelse(is.finite(market_return),
                            ifelse(market_return > 0, "POSITIVE", "NON_POSITIVE"), NA),
      market_volatility = ifelse(is.finite(market_vol),
                                 ifelse(market_vol > train_vol_threshold, "HIGH", "LOW"), NA),
      sector_trend = ifelse(is.finite(sector_return),
                            ifelse(sector_return > 0, "POSITIVE", "NON_POSITIVE"), NA),
      relative_strength = ifelse(is.finite(asset_return) & is.finite(sector_return),
                                 ifelse(asset_return - sector_return > 0, "POSITIVE", "NON_POSITIVE"), NA),
      stringsAsFactors = FALSE
    )
  )
}
environment_trades <- bind_rows(environment_rows)
stock_environment <- environment_trades[environment_trades$symbol != "SHY", , drop = FALSE]
environment_summary <- g5_mom012a_environment_summary(stock_environment)
environment_summary$support_status <- ifelse(
  environment_summary$trade_count >= audit_contract$environment_minimum_trades &
    environment_summary$asset_count >= audit_contract$environment_minimum_assets,
  "SUPPORTED", "LOW_SUPPORT"
)

stock_summary <- asset_summary[asset_summary$symbol != "SHY", , drop = FALSE]
bootstrap_metrics <- c(
  "excess_vs_buy_hold", "excess_vs_constant_exposure",
  "excess_vs_always_long_block", "selected_minus_fixed_250_25",
  "selected_minus_fixed_60_5"
)
clustered <- bind_rows(lapply(seq_along(bootstrap_metrics), function(i) {
  g5_mom012a_cluster_bootstrap(
    stock_summary,
    bootstrap_metrics[[i]],
    simulations = audit_contract$cluster_bootstrap_count,
    seed = audit_contract$cluster_bootstrap_seed + i
  )
}))
constant_lower <- clustered$lower_90[
  clustered$metric == "excess_vs_constant_exposure"
]
scorecard <- g5_mom012a_scorecard(
  stock_summary,
  constant_lower[[1L]],
  all(integrity$all_checks_pass)
)

score_values <- c(
  1,
  stats::median(stock_summary$excess_vs_buy_hold),
  mean(stock_summary$excess_vs_buy_hold > 0),
  stats::median(stock_summary$excess_vs_constant_exposure),
  stats::median(stock_summary$excess_vs_always_long_block),
  mean(stock_summary$selected_return > stock_summary$random_median_return),
  stats::median(stock_summary$observed_random_percentile),
  stats::median(stock_summary$selected_minus_fixed_250_25),
  stats::median(stock_summary$selected_minus_fixed_60_5),
  constant_lower[[1L]],
  stats::median(stock_summary$annualized_alpha)
)
scorecard$observed_value <- score_values
scorecard$interpretation <- c(
  "all asset integrity rows pass",
  "positive median required", "at least 55% required", "positive median required",
  "positive median required", "at least 55% required", "above 50% required",
  "positive median required", "positive median required", "positive lower bound required",
  paste0("positive median and positive-alpha breadth = ",
         percent(mean(stock_summary$annualized_alpha > 0)))
)

cohort_summary <- bind_rows(lapply(split(stock_summary, stock_summary$cohort), function(x) {
  data.frame(
    cohort = x$cohort[[1L]],
    asset_count = nrow(x),
    median_selected_return = stats::median(x$selected_return),
    median_buy_hold_return = stats::median(x$buy_hold_return),
    median_excess_buy_hold = stats::median(x$excess_vs_buy_hold),
    median_excess_constant = stats::median(x$excess_vs_constant_exposure),
    median_random_percentile = stats::median(x$observed_random_percentile),
    median_spy_beta = stats::median(x$spy_beta),
    median_annualized_alpha = stats::median(x$annualized_alpha),
    stringsAsFactors = FALSE
  )
}))

batch_summary <- data.frame(
  audit_id = audit_contract$audit_id,
  evidence_label = audit_contract$evidence_label,
  total_assets = nrow(asset_summary),
  stock_assets = nrow(stock_summary),
  strategy_beats_buy_hold = sum(stock_summary$excess_vs_buy_hold > 0),
  strategy_beats_constant_exposure = sum(stock_summary$excess_vs_constant_exposure > 0),
  strategy_beats_random_median = sum(stock_summary$selected_return > stock_summary$random_median_return),
  median_selected_return = stats::median(stock_summary$selected_return),
  median_buy_hold_return = stats::median(stock_summary$buy_hold_return),
  median_excess_buy_hold = stats::median(stock_summary$excess_vs_buy_hold),
  median_excess_constant_exposure = stats::median(stock_summary$excess_vs_constant_exposure),
  median_excess_always_long_block = stats::median(stock_summary$excess_vs_always_long_block),
  median_random_percentile = stats::median(stock_summary$observed_random_percentile),
  median_selected_minus_fixed_250_25 = stats::median(stock_summary$selected_minus_fixed_250_25),
  median_selected_minus_fixed_60_5 = stats::median(stock_summary$selected_minus_fixed_60_5),
  median_spy_beta = stats::median(stock_summary$spy_beta),
  median_annualized_alpha = stats::median(stock_summary$annualized_alpha),
  positive_alpha_assets = sum(stock_summary$annualized_alpha > 0),
  scorecard_passes = sum(scorecard$passed),
  scorecard_total = nrow(scorecard),
  confirmation_excluded = max(bars_all$session_date) < audit_contract$confirmation_start,
  stringsAsFactors = FALSE
)

# Human-facing visuals.
cohort_colors <- c(
  ATLAS_01_SECTOR_BALANCED = "#2B6CB0",
  DIVERSIFIED_CORE = "#2F855A",
  RETAIL_ATTENTION_2020 = "#C05621"
)
png(file.path(visual_dir, "audit01_strategy_vs_buy_hold.png"), 1500, 900, res = 150)
par(mar = c(5, 5, 4, 2))
plot(
  100 * stock_summary$buy_hold_return,
  100 * stock_summary$selected_return,
  pch = 19,
  col = cohort_colors[stock_summary$cohort],
  xlab = "Buy-and-hold cumulative return (%)",
  ylab = "LIT-MOM-01.2 cumulative return (%)",
  main = "Did timing beat simply owning the asset?"
)
abline(0, 1, lty = 2, col = "#4A5568", lwd = 2)
legend("topleft", legend = names(cohort_colors), col = cohort_colors, pch = 19, bty = "n", cex = 0.85)
grid(col = "#E2E8F0")
dev.off()

baseline_labels <- c("Buy & hold", "Constant exposure", "Always-long blocks", "Random median")
median_excess <- 100 * c(
  stats::median(stock_summary$excess_vs_buy_hold),
  stats::median(stock_summary$excess_vs_constant_exposure),
  stats::median(stock_summary$excess_vs_always_long_block),
  stats::median(stock_summary$selected_return - stock_summary$random_median_return)
)
breadth <- 100 * c(
  mean(stock_summary$excess_vs_buy_hold > 0),
  mean(stock_summary$excess_vs_constant_exposure > 0),
  mean(stock_summary$excess_vs_always_long_block > 0),
  mean(stock_summary$selected_return > stock_summary$random_median_return)
)
png(file.path(visual_dir, "audit01_baseline_scorecard.png"), 1600, 900, res = 150)
par(mfrow = c(1, 2), mar = c(8, 5, 4, 1))
barplot(median_excess, names.arg = baseline_labels, las = 2,
        col = ifelse(median_excess > 0, "#2F855A", "#C53030"),
        ylab = "Median strategy excess (percentage points)",
        main = "Median advantage")
abline(h = 0, col = "#1A202C")
barplot(breadth, names.arg = baseline_labels, las = 2,
        col = ifelse(breadth >= 55, "#2F855A", "#D69E2E"),
        ylim = c(0, 100), ylab = "Assets beaten (%)", main = "Cross-asset breadth")
abline(h = 55, lty = 2, col = "#4A5568")
dev.off()

png(file.path(visual_dir, "audit01_random_timing.png"), 1500, 900, res = 150)
par(mfrow = c(1, 2), mar = c(5, 5, 4, 1))
hist(100 * stock_summary$observed_random_percentile, breaks = seq(0, 100, by = 10),
     col = "#90CDF4", border = "white", xlab = "Observed return percentile (%)",
     main = "Selected timing vs matched random schedules")
abline(v = 50, lty = 2, col = "#4A5568", lwd = 2)
plot(100 * stock_summary$calendar_participation,
     100 * (stock_summary$selected_return - stock_summary$random_median_return),
     pch = 19, col = cohort_colors[stock_summary$cohort],
     xlab = "Calendar participation (%)", ylab = "Excess vs random median (pp)",
     main = "Timing value versus participation")
abline(h = 0, lty = 2, col = "#4A5568")
grid(col = "#E2E8F0")
dev.off()

png(file.path(visual_dir, "audit01_horizon_selection.png"), 1500, 900, res = 150)
par(mar = c(5, 12, 4, 2))
boxplot(
  100 * stock_summary$selected_minus_fixed_250_25,
  100 * stock_summary$selected_minus_fixed_60_5,
  names = c("Versus fixed 250/25", "Versus fixed 60/5"),
  horizontal = TRUE,
  las = 1,
  col = c("#BEE3F8", "#C6F6D5"),
  xlab = "Cumulative-return difference (percentage points)",
  main = "Did per-asset TRAIN selection add value?"
)
abline(v = 0, lty = 2, col = "#4A5568")
grid(col = "#EDF2F7")
dev.off()

supported_environment <- environment_summary[
  environment_summary$support_status == "SUPPORTED", , drop = FALSE
]
png(file.path(visual_dir, "audit01_environment.png"), 1700, 1000, res = 150)
par(mar = c(5, 13, 4, 2))
environment_key <- paste(
  supported_environment$descriptor,
  supported_environment$state,
  sep = "::"
)
environment_label_map <- c(
  "MARKET_TREND::NON_POSITIVE" = "Market down/flat",
  "MARKET_TREND::POSITIVE" = "Market up",
  "MARKET_VOLATILITY::HIGH" = "Market high-vol",
  "MARKET_VOLATILITY::LOW" = "Market low-vol",
  "SECTOR_TREND::NON_POSITIVE" = "Sector down/flat",
  "SECTOR_TREND::POSITIVE" = "Sector up",
  "RELATIVE_STRENGTH::NON_POSITIVE" = "Asset lagging sector",
  "RELATIVE_STRENGTH::POSITIVE" = "Asset leading sector",
  "MARKET_TREND_X_VOLATILITY::NON_POSITIVE / HIGH" = "Down/flat + high-vol",
  "MARKET_TREND_X_VOLATILITY::POSITIVE / HIGH" = "Up + high-vol",
  "MARKET_TREND_X_VOLATILITY::POSITIVE / LOW" = "Up + low-vol"
)
environment_labels <- unname(environment_label_map[environment_key])
if (anyNA(environment_labels)) {
  stop("Supported environment cell is missing a presentation label.", call. = FALSE)
}
environment_values <- 100 * supported_environment$mean_primary_trade_return
barplot(
  environment_values,
  names.arg = environment_labels,
  las = 1,
  horiz = TRUE,
  col = ifelse(environment_values > 0, "#2F855A", "#C53030"),
  xlab = "Mean primary trade return (%)",
  main = "Where did selected long trades work? Descriptive cells only"
)
abline(v = 0, col = "#1A202C")
dev.off()

png(file.path(visual_dir, "audit01_beta_alpha.png"), 1500, 900, res = 150)
par(mar = c(5, 5, 4, 2))
plot(
  stock_summary$spy_beta,
  100 * stock_summary$annualized_alpha,
  pch = 19,
  col = cohort_colors[stock_summary$cohort],
  xlab = "Daily-return beta versus SPY",
  ylab = "Annualized OLS intercept (%)",
  main = "How much remained after broad-market exposure?"
)
abline(h = 0, v = 0, lty = 2, col = "#4A5568")
grid(col = "#E2E8F0")
dev.off()

png(file.path(visual_dir, "audit01_diagnostic_scorecard.png"), 1700, 1000, res = 150)
par(mar = c(5, 18, 4, 2))
score_y <- rev(seq_len(nrow(scorecard)))
plot(c(0, 1), c(0.5, nrow(scorecard) + 0.5), type = "n", axes = FALSE,
     xlab = "", ylab = "", main = "Predeclared attribution diagnostics")
axis(2, at = score_y, labels = scorecard$diagnostic_id, las = 2, tick = FALSE, cex.axis = 0.8)
points(rep(0.5, nrow(scorecard)), score_y, pch = 19, cex = 2.3,
       col = ifelse(scorecard$passed, "#2F855A", "#C53030"))
text(rep(0.56, nrow(scorecard)), score_y,
     labels = ifelse(scorecard$passed, "PASS", "MISS"), pos = 4, cex = 0.85)
box()
dev.off()

contract_rows <- data.frame(
  field = names(audit_contract),
  value = vapply(audit_contract, function(x) paste(as.character(x), collapse = ","), character(1)),
  stringsAsFactors = FALSE
)
run_spec <- data.frame(
  audit_id = audit_contract$audit_id,
  run_id = run_id,
  as_of_timestamp = audit_contract$as_of_timestamp,
  train_window = paste(audit_contract$train_start, audit_contract$train_end, sep = " to "),
  retrospective_window = paste(audit_contract$retrospective_start, audit_contract$retrospective_end, sep = " to "),
  asset_count = nrow(asset_summary),
  stock_asset_count = nrow(stock_summary),
  random_schedules_per_asset = audit_contract$random_schedule_count,
  cluster_bootstrap_count = audit_contract$cluster_bootstrap_count,
  refresh_requested = refresh,
  max_observed_session = as.character(max(bars_all$session_date)),
  confirmation_excluded = max(bars_all$session_date) < audit_contract$confirmation_start,
  stringsAsFactors = FALSE
)

write_csv(contract_rows, file.path(output_dir, "audit01_frozen_contract.csv"))
write_csv(run_spec, file.path(output_dir, "audit01_run_spec.csv"))
write_csv(universe, file.path(output_dir, "audit01_universe.csv"))
write_csv(coverage, file.path(output_dir, "audit01_coverage.csv"))
write_csv(query$health, file.path(output_dir, "audit01_query_health.csv"))
write_csv(asset_summary, file.path(output_dir, "audit01_asset_summary.csv"))
write_csv(cohort_summary, file.path(output_dir, "audit01_cohort_summary.csv"))
write_csv(batch_summary, file.path(output_dir, "audit01_batch_summary.csv"))
write_csv(clustered, file.path(output_dir, "audit01_sector_cluster_bootstrap.csv"))
write_csv(scorecard, file.path(output_dir, "audit01_diagnostic_scorecard.csv"))
write_csv(integrity, file.path(output_dir, "audit01_integrity_audit.csv"))
write_csv(selected_trades, file.path(output_dir, "audit01_selected_trades.csv"))
write_csv(environment_trades, file.path(output_dir, "audit01_environment_trades.csv"))
write_csv(environment_summary, file.path(output_dir, "audit01_environment_summary.csv"))
write_csv(daily_paths, file.path(output_dir, "audit01_daily_paths.csv"))

report <- c(
  "# LIT-MOM-01.2 / AUDIT_01 Exposure and Selection Readout",
  "",
  paste0("Status: `RETROSPECTIVE_ATTRIBUTION_AUDIT_COMPLETE`; scorecard ",
         batch_summary$scorecard_passes, "/", batch_summary$scorecard_total, "."),
  "",
  "## Boundary",
  "",
  "This audit reuses the known 2021-2023 retrospective window. It does not",
  "change the strategy, nominate assets, form a portfolio, or query 2024+.",
  "",
  "## Baseline attribution",
  "",
  paste0("Across ", nrow(stock_summary), " stock paths, median strategy return was ",
         percent(batch_summary$median_selected_return), " versus ",
         percent(batch_summary$median_buy_hold_return), " for buy-and-hold."),
  paste0("The strategy beat buy-and-hold on ", batch_summary$strategy_beats_buy_hold,
         "/", nrow(stock_summary), " assets; median excess was ",
         percent(batch_summary$median_excess_buy_hold), "."),
  paste0("Median excess versus constant exposure was ",
         percent(batch_summary$median_excess_constant_exposure),
         "; versus always-long blocks it was ",
         percent(batch_summary$median_excess_always_long_block), "."),
  paste0("The selected timing beat the matched-random median on ",
         batch_summary$strategy_beats_random_median, "/", nrow(stock_summary),
         " assets; median random percentile was ",
         percent(batch_summary$median_random_percentile), "."),
  "",
  "## Horizon selection",
  "",
  paste0("Median selected-minus-fixed 250/25 return was ",
         percent(batch_summary$median_selected_minus_fixed_250_25), "."),
  paste0("Median selected-minus-fixed 60/5 return was ",
         percent(batch_summary$median_selected_minus_fixed_60_5), "."),
  "",
  "## Market attribution",
  "",
  paste0("Median daily-return SPY beta was ",
         formatC(batch_summary$median_spy_beta, digits = 3, format = "f"),
         "; median annualized OLS intercept was ",
         percent(batch_summary$median_annualized_alpha), "."),
  paste0(batch_summary$positive_alpha_assets, "/", nrow(stock_summary),
         " stock paths had a positive intercept."),
  "",
  "## Interpretation boundary",
  "",
  "The attribution diagnostics determine whether the lane warrants a separately",
  "frozen factor challenger. Environment cells are descriptive and cannot be",
  "converted into filters on this inspected window.",
  "",
  "## Packet",
  "",
  paste0("`", normalizePath(output_dir, winslash = "/", mustWork = FALSE), "`")
)
writeLines(report, file.path(output_dir, "audit01_report.md"))

message("LIT-MOM-01.2 AUDIT_01 complete.")
message("Packet: ", output_dir)
message("Scorecard: ", batch_summary$scorecard_passes, "/", batch_summary$scorecard_total)
