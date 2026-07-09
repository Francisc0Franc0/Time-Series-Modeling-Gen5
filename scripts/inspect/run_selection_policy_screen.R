# Compare Gen5.1 direct asset/state spec selection against Gen4-style pooled family selection.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)

source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "workbench_chart.R"))
source(file.path(repo_root, "R", "strategy_ema_cross.R"))
source(file.path(repo_root, "R", "strategy_bollinger_touch.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_poc.R"))
source(file.path(repo_root, "R", "wfa_ema_cross_multifold.R"))
source(file.path(repo_root, "R", "regime_pca_poc.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))
source(file.path(repo_root, "R", "selection_policy_screen.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

screen_stamp <- gsub("[^0-9A-Za-z]+", "", env_or("GEN5_SELECTION_POLICY_SCREEN_STAMP", "20260702"))
screen_id <- paste0("selection_policy_screen_A5_Q2Q3_", screen_stamp)
output_dir <- file.path(repo_root, "runs", "research_workbench", "selection_policy_screens", screen_id)
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

windows <- data.frame(
  window_id = c("2026Q2_asof_20260630", "2026Q3_asof_20260701"),
  quarter_id = c("2026Q2", "2026Q3"),
  as_of_timestamp = c("2026-06-30 17:30:00", "2026-07-01 17:30:00"),
  query_bars_csv = file.path(
    repo_root,
    "runs", "live_advice_bridge", "daily",
    c("2026Q2", "2026Q3"),
    c("20260630173000", "20260701173000"),
    "bridge_daily_query_bars.csv"
  ),
  stringsAsFactors = FALSE
)

quarters <- sort(unique(c(windows$quarter_id, vapply(windows$quarter_id, g5_bridge_previous_quarter_id, character(1L)))))
selection_policies <- c("asset_state_direct_spec", "pooled_family_asset_variant")

read_full_authority <- function(quarter_id) {
  authority_dir <- g5_bridge_authority_dir(repo_root, quarter_id)
  authority <- g5_bridge_read_authority(authority_dir)
  perf_path <- file.path(authority_dir, "bridge_train_state_performance.csv")
  if (!file.exists(perf_path)) {
    g5_stop(paste0("Missing bridge_train_state_performance.csv for ", quarter_id, ": ", perf_path))
  }
  authority$train_state_performance <- utils::read.csv(perf_path, stringsAsFactors = FALSE)
  authority
}

make_policy_authority <- function(authority, selection_policy) {
  out <- authority
  out$contract$selection_policy <- selection_policy
  if (identical(selection_policy, "asset_state_direct_spec")) {
    out$selected_states <- g5_selection_policy_add_direct_label(out$selected_states, out$train_state_performance, min_train_state_rows = 20L)
  } else if (identical(selection_policy, "pooled_family_asset_variant")) {
    out$selected_states <- g5_selection_policy_pooled_family_asset_variant(out$train_state_performance, min_train_state_rows = 20L)
  } else {
    g5_stop(paste0("Unsupported selection policy: ", selection_policy))
  }
  out
}

message("Gen5.1 selection-policy paired screen")
message("Output: ", output_dir)
message("Quarters: ", paste(quarters, collapse = ", "))
message("Policies: ", paste(selection_policies, collapse = ", "))

base_authorities <- stats::setNames(lapply(quarters, read_full_authority), quarters)
authorities <- list()
for (policy in selection_policies) {
  authorities[[policy]] <- stats::setNames(lapply(base_authorities, make_policy_authority, selection_policy = policy), quarters)
}

taxonomy <- data.frame(
  schema_version = g5_selection_policy_screen_schema_version(),
  selection_policy = selection_policies,
  description = c(
    "Current Gen5.1 policy: rank the full executable strategy spec inside each asset/state by TRAIN Sharpe, then TRAIN total return.",
    "Gen4-style policy: choose a state-level strategy family from pooled TRAIN evidence across assets, then choose asset-specific parameters inside that family."
  ),
  intended_variable = c("comparison_arm", "comparison_arm"),
  leakage_guardrail = c(
    "Uses TRAIN-only asset/state performance and freezes selected specs before replay.",
    "Uses TRAIN-only pooled family evidence and TRAIN-only asset parameter selection before replay."
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = g5_selection_policy_screen_schema_version(),
  screen_id = screen_id,
  symbols = paste(g5_bridge_default_symbols(), collapse = ","),
  context_symbols = paste(g5_bridge_default_context_symbols(), collapse = ","),
  quarters_required = paste(quarters, collapse = ","),
  replay_windows = paste(windows$window_id, collapse = ","),
  pca_panel_mode = "pooled_asset_day",
  pca_panel_label = "long_pca_behavioral_pool",
  state_engine = "quantile_grid",
  grid_n = 5L,
  strategy_grid_preset = "gen4_daily_default",
  min_train_state_rows = 20L,
  intended_variable = "selection_policy_only",
  research_only = TRUE,
  stringsAsFactors = FALSE
)

direct_states <- g5_wfa_bind_rows_fill(lapply(authorities$asset_state_direct_spec, function(x) x$selected_states))
pooled_states <- g5_wfa_bind_rows_fill(lapply(authorities$pooled_family_asset_variant, function(x) x$selected_states))
comparison <- g5_selection_policy_compare_selected_states(direct_states, pooled_states)

agreement_by_quarter <- do.call(rbind, lapply(split(comparison, comparison$quarter_id), function(x) {
  data.frame(
    quarter_id = as.character(x$quarter_id[[1L]]),
    state_asset_rows = nrow(x),
    family_match_count = sum(x$family_match, na.rm = TRUE),
    family_match_rate = mean(x$family_match, na.rm = TRUE),
    spec_match_count = sum(x$spec_match, na.rm = TRUE),
    spec_match_rate = mean(x$spec_match, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))
agreement_overall <- data.frame(
  quarter_id = "ALL",
  state_asset_rows = nrow(comparison),
  family_match_count = sum(comparison$family_match, na.rm = TRUE),
  family_match_rate = mean(comparison$family_match, na.rm = TRUE),
  spec_match_count = sum(comparison$spec_match, na.rm = TRUE),
  spec_match_rate = mean(comparison$spec_match, na.rm = TRUE),
  stringsAsFactors = FALSE
)
agreement_summary <- rbind(agreement_by_quarter, agreement_overall)

packet_rows <- list()
summary_rows <- list()
book_rows <- list()
trade_rows <- list()
for (i in seq_len(nrow(windows))) {
  window <- windows[i, , drop = FALSE]
  if (!file.exists(window$query_bars_csv[[1L]])) {
    g5_stop(paste0("Missing cached daily query bars for ", window$window_id[[1L]], ": ", window$query_bars_csv[[1L]]))
  }
  bars <- utils::read.csv(window$query_bars_csv[[1L]], stringsAsFactors = FALSE)
  bars$session_date <- as.Date(bars$session_date)
  previous_quarter <- g5_bridge_previous_quarter_id(window$quarter_id[[1L]])
  for (policy in selection_policies) {
    message("Replay: ", window$window_id[[1L]], " / ", policy)
    daily <- g5_selection_policy_run_daily_continuity_fast(
      bars,
      current_authority = authorities[[policy]][[window$quarter_id[[1L]]]],
      previous_authority = authorities[[policy]][[previous_quarter]],
      as_of_timestamp = window$as_of_timestamp[[1L]]
    )
    daily$contract$selection_policy <- policy
    if (!is.null(daily$previous_contract)) daily$previous_contract$selection_policy <- policy
    for (field in c("replay", "pending_actions", "executions", "trades", "operator_packet", "book_summary", "continuity")) {
      if (!is.null(daily[[field]]) && is.data.frame(daily[[field]]) && nrow(daily[[field]])) {
        daily[[field]]$selection_policy <- policy
        daily[[field]]$window_id <- window$window_id[[1L]]
      }
    }
    policy_dir <- file.path(output_dir, window$window_id[[1L]], policy)
    paths <- g5_bridge_write_daily_outputs(daily, policy_dir, chart_lookback_days = 90L)
    packet_rows[[length(packet_rows) + 1L]] <- data.frame(
      schema_version = g5_selection_policy_screen_schema_version(),
      window_id = window$window_id[[1L]],
      quarter_id = window$quarter_id[[1L]],
      previous_quarter_id = previous_quarter,
      as_of_timestamp = window$as_of_timestamp[[1L]],
      selection_policy = policy,
      packet_dir = normalizePath(policy_dir, winslash = "/", mustWork = FALSE),
      report_md = normalizePath(paths$report_md, winslash = "/", mustWork = FALSE),
      contact_sheet_png = normalizePath(paths$contact_sheet_png, winslash = "/", mustWork = FALSE),
      trades_csv = normalizePath(paths$trades_csv, winslash = "/", mustWork = FALSE),
      replay_csv = normalizePath(paths$replay_csv, winslash = "/", mustWork = FALSE),
      stringsAsFactors = FALSE
    )
    summary_rows[[length(summary_rows) + 1L]] <- g5_selection_policy_summarize_daily(daily, policy, window$window_id[[1L]])
    if (is.data.frame(daily$book_summary) && nrow(daily$book_summary)) book_rows[[length(book_rows) + 1L]] <- daily$book_summary
    if (is.data.frame(daily$trades) && nrow(daily$trades)) trade_rows[[length(trade_rows) + 1L]] <- daily$trades
  }
}

packet_index <- g5_wfa_bind_rows_fill(packet_rows)
trade_summary <- g5_wfa_bind_rows_fill(summary_rows)
book_summary <- g5_wfa_bind_rows_fill(book_rows)
trade_ledger <- if (length(trade_rows)) g5_wfa_bind_rows_fill(trade_rows) else data.frame()

portfolio_proxy <- do.call(rbind, lapply(split(trade_summary, paste(trade_summary$window_id, trade_summary$selection_policy, sep = "::")), function(x) {
  data.frame(
    window_id = as.character(x$window_id[[1L]]),
    selection_policy = as.character(x$selection_policy[[1L]]),
    symbol_count = nrow(x),
    trade_count = sum(x$trade_count, na.rm = TRUE),
    open_trade_count = sum(x$open_trade_count, na.rm = TRUE),
    equal_symbol_mean_compound_trace_return = mean(x$compound_trace_return, na.rm = TRUE),
    worst_symbol_compound_trace_return = min(x$compound_trace_return, na.rm = TRUE),
    best_symbol_compound_trace_return = max(x$compound_trace_return, na.rm = TRUE),
    stringsAsFactors = FALSE
  )
}))

paths <- list(
  run_spec_csv = file.path(output_dir, "selection_policy_run_spec.csv"),
  taxonomy_csv = file.path(output_dir, "selection_policy_taxonomy.csv"),
  selected_states_csv = file.path(output_dir, "selection_policy_selected_states_all.csv"),
  selected_state_comparison_csv = file.path(output_dir, "selection_policy_selected_state_comparison.csv"),
  agreement_summary_csv = file.path(output_dir, "selection_policy_agreement_summary.csv"),
  packet_index_csv = file.path(output_dir, "selection_policy_packet_index.csv"),
  book_summary_csv = file.path(output_dir, "selection_policy_book_summary.csv"),
  trade_ledger_csv = file.path(output_dir, "selection_policy_trade_ledger.csv"),
  trade_summary_csv = file.path(output_dir, "selection_policy_trade_summary.csv"),
  portfolio_proxy_csv = file.path(output_dir, "selection_policy_portfolio_proxy_summary.csv"),
  report_md = file.path(output_dir, "selection_policy_screen_report.md")
)
g5_wfa_write_csv(run_spec, paths$run_spec_csv)
g5_wfa_write_csv(taxonomy, paths$taxonomy_csv)
g5_wfa_write_csv(g5_wfa_bind_rows_fill(list(direct_states, pooled_states)), paths$selected_states_csv)
g5_wfa_write_csv(comparison, paths$selected_state_comparison_csv)
g5_wfa_write_csv(agreement_summary, paths$agreement_summary_csv)
g5_wfa_write_csv(packet_index, paths$packet_index_csv)
g5_wfa_write_csv(book_summary, paths$book_summary_csv)
g5_wfa_write_csv(trade_ledger, paths$trade_ledger_csv)
g5_wfa_write_csv(trade_summary, paths$trade_summary_csv)
g5_wfa_write_csv(portfolio_proxy, paths$portfolio_proxy_csv)

md_table <- function(df, cols, n = Inf) {
  if (!is.data.frame(df) || !nrow(df)) return("_No rows._")
  df <- df[seq_len(min(nrow(df), n)), cols, drop = FALSE]
  df[] <- lapply(df, as.character)
  c(
    paste0("| ", paste(cols, collapse = " | "), " |"),
    paste0("| ", paste(rep("---", length(cols)), collapse = " | "), " |"),
    apply(df, 1L, function(row) paste0("| ", paste(row, collapse = " | "), " |"))
  )
}

report <- c(
  "# Gen5.1 Selection-Policy Paired Screen",
  "",
  "## Plain-Language Purpose",
  "",
  "This screen asks whether the current Gen5.1 selection policy is helping or hurting relative to the Gen4-style policy it replaced. Pooled PCA still matters in the Gen5.1 approach because it creates shared regime labels from a larger context universe: each asset-day is mapped into a common state space such as `S2_4`. After that, current Gen5.1 selects the full strategy spec separately inside each asset/state. That means the pooling improves the regime definition, but it does not pool the final strategy-performance decision. The Gen4-style alternative adds one more pooling step: choose the state-level strategy family from pooled TRAIN evidence, then choose parameters per asset inside that family.",
  "",
  "The comparison varies only that selection-policy step. It does not accept performance as allocation evidence and it does not change live bridge behavior.",
  "",
  "## Run Spec",
  "",
  paste0("- Screen ID: `", screen_id, "`"),
  paste0("- Symbols: `", run_spec$symbols[[1L]], "`"),
  paste0("- Context universe: `", run_spec$context_symbols[[1L]], "`"),
  "- PCA surface: long/pooled asset-day PCA (`pooled_asset_day`)",
  "- State map: `5x5` quantile grid",
  "- Strategy grid: `gen4_daily_default` implemented subset",
  paste0("- Replay windows: `", run_spec$replay_windows[[1L]], "`"),
  "",
  "## Selection-Map Agreement",
  "",
  md_table(agreement_summary, c("quarter_id", "state_asset_rows", "family_match_count", "family_match_rate", "spec_match_count", "spec_match_rate")),
  "",
  "## Portfolio-Proxy Inspection Summary",
  "",
  "This is a compact trace-return proxy over replayed bridge trades, included only to make behavior inspectable before deciding whether to run a larger portfolio-accounting batch.",
  "",
  md_table(portfolio_proxy, c("window_id", "selection_policy", "symbol_count", "trade_count", "open_trade_count", "equal_symbol_mean_compound_trace_return", "worst_symbol_compound_trace_return", "best_symbol_compound_trace_return")),
  "",
  "## Artifacts",
  "",
  paste0("- Run spec: `", paths$run_spec_csv, "`"),
  paste0("- Taxonomy: `", paths$taxonomy_csv, "`"),
  paste0("- Selected-state comparison: `", paths$selected_state_comparison_csv, "`"),
  paste0("- Agreement summary: `", paths$agreement_summary_csv, "`"),
  paste0("- Packet index: `", paths$packet_index_csv, "`"),
  paste0("- Trade summary: `", paths$trade_summary_csv, "`"),
  paste0("- Portfolio proxy summary: `", paths$portfolio_proxy_csv, "`"),
  "",
  "## Guardrails",
  "",
  "- Pooled family selection uses only TRAIN performance rows from frozen bridge authority packets.",
  "- Asset-specific parameter selection inside the pooled family also uses TRAIN rows only.",
  "- Q2 and Q3 replay consume frozen maps and cached query bars.",
  "- The live advice bridge default remains unchanged until the operator makes an explicit STOP decision."
)
writeLines(unlist(report), paths$report_md, useBytes = TRUE)

message("")
message("Selection-policy screen complete:")
print(data.frame(paths), row.names = FALSE)
message("")
message("Agreement summary:")
print(agreement_summary, row.names = FALSE)
message("")
message("Portfolio proxy:")
print(portfolio_proxy, row.names = FALSE)
