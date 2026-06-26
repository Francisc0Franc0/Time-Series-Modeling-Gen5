# Gen5.1 multi-asset WFA batch diagnostic.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
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
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "workbench_data_proof.R"))
source(file.path(repo_root, "R", "strategy_ema_cross.R"))
source(file.path(repo_root, "R", "strategy_bollinger_touch.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))

g5_batch_parse_int_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive integers."))
  }
  raw <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  raw <- raw[nzchar(raw)]
  parsed <- suppressWarnings(as.integer(raw))
  if (length(parsed) == 0L || any(is.na(parsed)) || any(parsed < 1L)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive integers."))
  }
  sort(unique(parsed))
}

g5_batch_parse_num_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive numbers."))
  }
  raw <- trimws(strsplit(value, ",", fixed = TRUE)[[1L]])
  raw <- raw[nzchar(raw)]
  parsed <- suppressWarnings(as.numeric(raw))
  if (length(parsed) == 0L || any(is.na(parsed)) || any(parsed <= 0)) {
    g5_stop(paste0(label, " must be a comma-separated list of positive numbers."))
  }
  sort(unique(parsed))
}

g5_batch_parse_character_list_env <- function(value, label) {
  if (!nzchar(value)) {
    g5_stop(paste0(label, " must be a comma-separated list."))
  }
  raw <- unique(trimws(strsplit(value, ",", fixed = TRUE)[[1L]]))
  raw <- raw[nzchar(raw)]
  if (length(raw) == 0L) {
    g5_stop(paste0(label, " must be a comma-separated list."))
  }
  raw
}

g5_batch_fmt_pct <- function(x) {
  ifelse(is.na(x), "NA", sprintf("%.2f%%", 100 * as.numeric(x)))
}

g5_batch_fmt_num <- function(x) {
  ifelse(is.na(x), "NA", ifelse(is.infinite(x), "Inf", sprintf("%.3f", as.numeric(x))))
}

g5_multi_asset_wfa_batch_prefix <- function(as_of_timestamp, symbols, wfa_start_date, wfa_end_date, fold_count) {
  stamp <- gsub("[^0-9A-Za-z]+", "", as.character(as_of_timestamp))
  symbols <- g5_standardize_symbol(symbols)
  window_label <- paste0(
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_start_date))),
    "_",
    gsub("[^0-9A-Za-z]+", "", as.character(as.Date(wfa_end_date)))
  )
  paste(c("mawfa", paste0(length(symbols), "a"), paste0(fold_count, "f"), window_label, stamp), collapse = "_")
}

g5_multi_asset_table_lines <- function(df, cols) {
  df <- df[, cols, drop = FALSE]
  header <- paste(c("", names(df), ""), collapse = " | ")
  sep <- paste(c("", rep("---", ncol(df)), ""), collapse = " | ")
  rows <- apply(df, 1, function(row) paste(c("", as.character(row), ""), collapse = " | "))
  c(header, sep, rows)
}

g5_write_multi_asset_wfa_batch_report <- function(batch_summary, selected_specs, path, settings) {
  dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  printable <- batch_summary
  for (col in c("total_return", "cagr", "max_drawdown", "buy_hold_total_return", "buy_hold_max_drawdown")) {
    printable[[col]] <- g5_batch_fmt_pct(printable[[col]])
  }
  printable$sharpe <- g5_batch_fmt_num(printable$sharpe)
  printable$buy_hold_sharpe <- g5_batch_fmt_num(printable$buy_hold_sharpe)

  spec_print <- selected_specs
  spec_print$train_sharpe <- g5_batch_fmt_num(spec_print$train_sharpe)
  spec_print$train_total_return <- g5_batch_fmt_pct(spec_print$train_total_return)

  lines <- c(
    "# Multi-Asset WFA Batch Diagnostic",
    "",
    "Proof-of-concept only: each asset is trained, selected, and traded independently. This batch report aggregates outputs only; it does not pool TRAIN data or select a global strategy spec.",
    "",
    "## Run Context",
    "",
    paste0("- Symbols: `", paste(settings$symbols, collapse = ", "), "`"),
    paste0("- As-of timestamp: `", settings$as_of_timestamp, "`"),
    paste0("- WFA analysis window: `", settings$wfa_start_date, " to ", settings$wfa_end_date, "`"),
    paste0("- Train period: `", settings$train_quarters, " quarters`"),
    paste0("- OOS period: `", settings$oos_quarters, " quarter(s)`"),
    paste0("- Fold count: `", settings$fold_count, "`"),
    paste0("- Candidate families: `", paste(settings$candidate_families, collapse = ", "), "`"),
    paste0("- Exit stack max-hold sessions: `", paste(settings$max_hold_sessions, collapse = ", "), "`"),
    paste0("- Exit stack stop-loss percentages: `", paste(sprintf("%.1f%%", 100 * as.numeric(settings$stop_loss_pcts)), collapse = ", "), "`"),
    paste0("- Exit stack take-profit percentages: `", paste(sprintf("%.1f%%", 100 * as.numeric(settings$take_profit_pcts)), collapse = ", "), "`"),
    "",
    "## Asset Summary",
    "",
    g5_multi_asset_table_lines(
      printable,
      c("symbol", "total_return", "sharpe", "max_drawdown", "trade_count", "native_exit_count", "exit_stack_exit_count", "buy_hold_total_return", "strategy_chart_png")
    ),
    "",
    "## Fold-Selected Strategy Specs",
    "",
    g5_multi_asset_table_lines(
      spec_print,
      c("symbol", "fold_id", "strategy_family", "model_instance_id", "exit_stack_id", "strategy_spec_id", "train_sharpe", "train_total_return")
    ),
    "",
    "## Audit Notes",
    "",
    "- Each asset contributes its own independent TRAIN folds and selected OOS path.",
    "- Cross-asset rows are summaries of independently generated WFA packets.",
    "- Native exits and exit-stack exits are counted from each selected stitched OOS trade ledger."
  )
  writeLines(lines, con = path, useBytes = TRUE)
  invisible(normalizePath(path, winslash = "/", mustWork = FALSE))
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_env <- Sys.getenv("GEN5_WFA_BATCH_AS_OF_TIMESTAMP", unset = Sys.getenv("GEN5_AS_OF_TIMESTAMP", unset = ""))
if (!nzchar(as_of_env)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP is required for multi-asset WFA batch.")
}
as_of_timestamp <- as.POSIXct(as_of_env, tz = cfg$calendar$timezone)
if (is.na(as_of_timestamp)) {
  g5_stop("GEN5_AS_OF_TIMESTAMP could not be parsed as a timestamp.")
}

symbols <- g5_standardize_symbol(g5_batch_parse_character_list_env(Sys.getenv("GEN5_WFA_BATCH_SYMBOLS", unset = "AMD,NVDA,TSLA,META,QQQ,SPY"), "GEN5_WFA_BATCH_SYMBOLS"))
if (length(symbols) < 1L) {
  g5_stop("GEN5_WFA_BATCH_SYMBOLS must include at least one symbol.")
}

end_env <- Sys.getenv("GEN5_WFA_BATCH_END_DATE", unset = "")
if (!nzchar(end_env)) {
  g5_stop("GEN5_WFA_BATCH_END_DATE is required.")
}
wfa_end_date <- as.Date(end_env)
if (is.na(wfa_end_date)) {
  g5_stop("GEN5_WFA_BATCH_END_DATE could not be parsed as a date.")
}

train_quarters <- g5_ema_cross_wfa_validate_quarters(suppressWarnings(as.numeric(Sys.getenv("GEN5_WFA_BATCH_TRAIN_QUARTERS", unset = "8"))), "GEN5_WFA_BATCH_TRAIN_QUARTERS")
oos_quarters <- g5_ema_cross_wfa_validate_quarters(suppressWarnings(as.numeric(Sys.getenv("GEN5_WFA_BATCH_OOS_QUARTERS", unset = "1"))), "GEN5_WFA_BATCH_OOS_QUARTERS")
fold_count <- suppressWarnings(as.integer(Sys.getenv("GEN5_WFA_BATCH_FOLD_COUNT", unset = "3")))
if (is.na(fold_count) || fold_count < 1L) {
  g5_stop("GEN5_WFA_BATCH_FOLD_COUNT must be a positive integer.")
}

start_env <- Sys.getenv("GEN5_WFA_BATCH_START_DATE", unset = "")
lookback_env <- Sys.getenv("GEN5_WFA_BATCH_LOOKBACK_DAYS", unset = "")
if (nzchar(start_env)) {
  wfa_start_date <- as.Date(start_env)
  if (is.na(wfa_start_date)) {
    g5_stop("GEN5_WFA_BATCH_START_DATE could not be parsed as a date.")
  }
} else if (nzchar(lookback_env)) {
  lookback_days <- suppressWarnings(as.integer(lookback_env))
  if (is.na(lookback_days) || lookback_days < 1L) {
    g5_stop("GEN5_WFA_BATCH_LOOKBACK_DAYS must be a positive integer when supplied.")
  }
  wfa_start_date <- wfa_end_date - lookback_days
} else {
  wfa_start_date <- wfa_end_date - (g5_ema_cross_wfa_quarters_to_days(train_quarters) + fold_count * g5_ema_cross_wfa_quarters_to_days(oos_quarters) + 2L)
}
if (wfa_start_date > wfa_end_date) {
  g5_stop("Multi-asset WFA start date cannot be after end date.")
}

fast_periods <- g5_batch_parse_int_list_env(Sys.getenv("GEN5_WFA_BATCH_FAST_PERIODS", unset = "8,12,20"), "GEN5_WFA_BATCH_FAST_PERIODS")
slow_periods <- g5_batch_parse_int_list_env(Sys.getenv("GEN5_WFA_BATCH_SLOW_PERIODS", unset = "30,50,80,120"), "GEN5_WFA_BATCH_SLOW_PERIODS")
if (!any(outer(fast_periods, slow_periods, FUN = "<"))) {
  g5_stop("Multi-asset WFA EMA grid must include at least one fast_period < slow_period pair.")
}
bb_lookback_periods <- g5_batch_parse_int_list_env(Sys.getenv("GEN5_WFA_BATCH_BB_LOOKBACK_PERIODS", unset = "10,20,30"), "GEN5_WFA_BATCH_BB_LOOKBACK_PERIODS")
bb_sd_multipliers <- g5_batch_parse_num_list_env(Sys.getenv("GEN5_WFA_BATCH_BB_SD_MULTIPLIERS", unset = "1.5,2,2.5"), "GEN5_WFA_BATCH_BB_SD_MULTIPLIERS")
candidate_families <- g5_wfa_candidate_families(g5_batch_parse_character_list_env(Sys.getenv("GEN5_WFA_BATCH_CANDIDATE_FAMILIES", unset = "ema_cross,bollinger_touch"), "GEN5_WFA_BATCH_CANDIDATE_FAMILIES"))
max_hold_sessions <- g5_batch_parse_int_list_env(Sys.getenv("GEN5_WFA_BATCH_MAX_HOLD_SESSIONS", unset = "10,20,40"), "GEN5_WFA_BATCH_MAX_HOLD_SESSIONS")
stop_loss_pcts <- g5_batch_parse_num_list_env(Sys.getenv("GEN5_WFA_BATCH_STOP_LOSS_PCTS", unset = "0.10"), "GEN5_WFA_BATCH_STOP_LOSS_PCTS")
take_profit_pcts <- g5_batch_parse_num_list_env(Sys.getenv("GEN5_WFA_BATCH_TAKE_PROFIT_PCTS", unset = "0.25"), "GEN5_WFA_BATCH_TAKE_PROFIT_PCTS")
refresh <- g5_parse_bool_env(Sys.getenv("GEN5_WFA_BATCH_REFRESH", unset = ""), default = FALSE)

warmup_days <- max(c(slow_periods, bb_lookback_periods)) * 4L
query_start_date <- wfa_start_date - warmup_days
batch_prefix <- g5_multi_asset_wfa_batch_prefix(as_of_timestamp, symbols, wfa_start_date, wfa_end_date, fold_count)
batch_dir <- file.path(repo_root, "runs", "research_workbench", "wfa_pocs", batch_prefix)
dir.create(batch_dir, recursive = TRUE, showWarnings = FALSE)

message("Gen5 multi-asset WFA batch diagnostic")
message("Repository: ", repo_root)
message("Cache root: ", cfg$cache$root)
message("Symbols: ", paste(symbols, collapse = ", "))
message("WFA window: ", as.character(wfa_start_date), " to ", as.character(wfa_end_date))
message("Query window with indicator warmup: ", as.character(query_start_date), " to ", as.character(wfa_end_date))
message("As of: ", as.character(as_of_timestamp))
message("Fold count: ", fold_count)
message("Refresh: ", refresh)
message("Batch output: ", batch_dir)
message("POC only: each asset is trained and selected independently; this report aggregates outputs only.")

summary_rows <- list()
selected_rows <- list()
path_rows <- list()

for (symbol in symbols) {
  message("")
  message("== Running independent WFA for ", symbol, " ==")
  result <- g5_workbench_query_adjusted_daily_bars(
    cfg = cfg,
    start_date = query_start_date,
    end_date = wfa_end_date,
    as_of_timestamp = as_of_timestamp,
    symbols = symbol,
    universe_name = paste0("multi_asset_wfa_batch_", symbol),
    universe_roles = "research_universe",
    refresh = refresh,
    repo_root = repo_root
  )
  g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
  symbol_dir <- file.path(batch_dir, symbol)
  dir.create(symbol_dir, recursive = TRUE, showWarnings = FALSE)
  written <- g5_write_ema_cross_wfa_multi_outputs(
    result,
    symbol = symbol,
    output_dir = symbol_dir,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    fast_periods = fast_periods,
    slow_periods = slow_periods,
    bb_lookback_periods = bb_lookback_periods,
    bb_sd_multipliers = bb_sd_multipliers,
    candidate_families = candidate_families,
    max_hold_sessions = max_hold_sessions,
    stop_loss_pcts = stop_loss_pcts,
    take_profit_pcts = take_profit_pcts,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    fold_count = fold_count
  )
  metrics <- written$stitched_metrics[1L, , drop = FALSE]
  summary_rows[[length(summary_rows) + 1L]] <- data.frame(
    symbol = symbol,
    total_return = metrics$total_return[[1L]],
    cagr = metrics$cagr[[1L]],
    sharpe = metrics$sharpe[[1L]],
    max_drawdown = metrics$max_drawdown[[1L]],
    trade_count = metrics$trade_count[[1L]],
    closed_trade_count = metrics$closed_trade_count[[1L]],
    open_trade_count = metrics$open_trade_count[[1L]],
    native_exit_count = metrics$native_exit_count[[1L]],
    exit_stack_exit_count = metrics$exit_stack_exit_count[[1L]],
    buy_hold_total_return = metrics$buy_hold_total_return[[1L]],
    buy_hold_sharpe = metrics$buy_hold_sharpe[[1L]],
    buy_hold_max_drawdown = metrics$buy_hold_max_drawdown[[1L]],
    strategy_chart_png = written$paths$stitched_strategy_chart_png,
    equity_curve_png = written$paths$stitched_equity_curve_png,
    metrics_md = written$paths$stitched_metrics_md,
    stringsAsFactors = FALSE
  )
  selected <- written$selected_models
  selected$symbol <- symbol
  selected_rows[[length(selected_rows) + 1L]] <- selected
  path_rows[[length(path_rows) + 1L]] <- data.frame(
    symbol = symbol,
    output_dir = normalizePath(symbol_dir, winslash = "/", mustWork = FALSE),
    strategy_chart_png = written$paths$stitched_strategy_chart_png,
    equity_curve_png = written$paths$stitched_equity_curve_png,
    metrics_md = written$paths$stitched_metrics_md,
    selected_models_csv = written$paths$selected_models_csv,
    trades_csv = written$paths$stitched_trades_csv,
    stringsAsFactors = FALSE
  )
  message("  Return: ", g5_batch_fmt_pct(metrics$total_return[[1L]]))
  message("  Sharpe: ", g5_batch_fmt_num(metrics$sharpe[[1L]]))
  message("  Max drawdown: ", g5_batch_fmt_pct(metrics$max_drawdown[[1L]]))
  message("  Native exits: ", metrics$native_exit_count[[1L]], " | Exit-stack exits: ", metrics$exit_stack_exit_count[[1L]])
}

batch_summary <- do.call(rbind, summary_rows)
selected_specs <- do.call(rbind, selected_rows)
path_index <- do.call(rbind, path_rows)

batch_summary <- batch_summary[order(ifelse(is.na(batch_summary$sharpe), -Inf, batch_summary$sharpe), decreasing = TRUE), , drop = FALSE]
selected_specs <- selected_specs[order(selected_specs$symbol, selected_specs$fold_no), , drop = FALSE]
path_index <- path_index[order(path_index$symbol), , drop = FALSE]
rownames(batch_summary) <- NULL
rownames(selected_specs) <- NULL
rownames(path_index) <- NULL

batch_summary_csv <- file.path(batch_dir, paste0(batch_prefix, "_asset_summary.csv"))
selected_specs_csv <- file.path(batch_dir, paste0(batch_prefix, "_selected_specs_by_fold.csv"))
path_index_csv <- file.path(batch_dir, paste0(batch_prefix, "_path_index.csv"))
batch_report_md <- file.path(batch_dir, paste0(batch_prefix, "_batch_report.md"))

utils::write.csv(batch_summary, batch_summary_csv, row.names = FALSE)
utils::write.csv(selected_specs, selected_specs_csv, row.names = FALSE)
utils::write.csv(path_index, path_index_csv, row.names = FALSE)
g5_write_multi_asset_wfa_batch_report(
  batch_summary,
  selected_specs,
  batch_report_md,
  settings = list(
    symbols = symbols,
    as_of_timestamp = as_of_timestamp,
    wfa_start_date = wfa_start_date,
    wfa_end_date = wfa_end_date,
    train_quarters = train_quarters,
    oos_quarters = oos_quarters,
    fold_count = fold_count,
    candidate_families = candidate_families,
    max_hold_sessions = max_hold_sessions,
    stop_loss_pcts = stop_loss_pcts,
    take_profit_pcts = take_profit_pcts
  )
)

message("")
message("Batch asset summary:")
print(batch_summary[, c("symbol", "total_return", "sharpe", "max_drawdown", "trade_count", "native_exit_count", "exit_stack_exit_count", "buy_hold_total_return")], row.names = FALSE)
message("")
message("Batch outputs:")
message("  Asset summary CSV: ", normalizePath(batch_summary_csv, winslash = "/", mustWork = FALSE))
message("  Selected specs CSV: ", normalizePath(selected_specs_csv, winslash = "/", mustWork = FALSE))
message("  Path index CSV: ", normalizePath(path_index_csv, winslash = "/", mustWork = FALSE))
message("  Batch report MD: ", normalizePath(batch_report_md, winslash = "/", mustWork = FALSE))
