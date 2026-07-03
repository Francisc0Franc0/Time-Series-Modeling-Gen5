# Run a temporary dual-policy live-advice bridge daily packet.

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
source(file.path(repo_root, "R", "regime_pca_poc.R"))
source(file.path(repo_root, "R", "regime_pca_wfa_poc.R"))
source(file.path(repo_root, "R", "live_advice_bridge.R"))
source(file.path(repo_root, "R", "selection_policy_screen.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}

parse_args <- function(args) {
  out <- list()
  for (arg in args) {
    if (!grepl("^--[^=]+=", arg)) next
    key <- sub("^--", "", sub("=.*$", "", arg))
    value <- sub("^[^=]+=", "", arg)
    out[[gsub("-", "_", key)]] <- value
  }
  out
}

arg <- parse_args(commandArgs(trailingOnly = TRUE))
arg_or_env <- function(arg_name, env_name, default = "") {
  value <- arg[[arg_name]]
  if (!is.null(value) && nzchar(value)) value else env_or(env_name, default)
}

g5_bridge_dual_policy_specs <- function() {
  data.frame(
    selection_policy = c("pooled_family_asset_variant", "asset_state_direct_spec"),
    policy_short_label = c("Gen4-style pooled-family", "Gen5.1 direct-spec"),
    output_slug = c("gen4_pooled_family", "gen5_1_direct_spec"),
    description = c(
      "Gen4-style lane: choose a state-level family from pooled TRAIN evidence, then choose asset-specific params inside that family.",
      "Gen5.1 lane: choose the best full asset/state strategy spec directly from TRAIN evidence."
    ),
    stringsAsFactors = FALSE
  )
}

g5_bridge_apply_selection_policy <- function(authority, selection_policy, min_train_state_rows = 20L) {
  out <- authority
  out$contract$selection_policy <- selection_policy
  if (identical(selection_policy, "asset_state_direct_spec")) {
    out$selected_states <- g5_selection_policy_add_direct_label(out$selected_states)
  } else if (identical(selection_policy, "pooled_family_asset_variant")) {
    if (!is.data.frame(out$train_state_performance) || !nrow(out$train_state_performance)) {
      g5_stop("Pooled-family live advice requires bridge_train_state_performance.csv in the authority packet.")
    }
    out$selected_states <- g5_selection_policy_pooled_family_asset_variant(
      out$train_state_performance,
      min_train_state_rows = min_train_state_rows
    )
  } else {
    g5_stop(paste0("Unsupported live advice selection policy: ", selection_policy))
  }
  out
}

g5_bridge_tag_daily_policy <- function(daily, selection_policy, policy_label) {
  daily$selection_policy <- selection_policy
  daily$selection_policy_label <- policy_label
  for (field in c("replay", "pending_actions", "executions", "trades", "operator_packet", "book_summary", "continuity")) {
    if (is.data.frame(daily[[field]]) && nrow(daily[[field]])) {
      daily[[field]]$selection_policy <- selection_policy
      daily[[field]]$selection_policy_label <- policy_label
    }
  }
  daily
}

g5_bridge_pending_action_for_symbol <- function(pending, symbol) {
  if (!is.data.frame(pending) || !nrow(pending)) return("NONE")
  rows <- pending[as.character(pending$symbol) == as.character(symbol), , drop = FALSE]
  if (!nrow(rows)) return("NONE")
  paste(unique(as.character(rows$action)), collapse = ";")
}

g5_bridge_advice_text <- function(position, pending_action) {
  position <- as.character(position)
  pending_action <- as.character(pending_action)
  if (!identical(pending_action, "NONE")) {
    return(paste0("PENDING NEXT-OPEN ACTION: ", pending_action))
  }
  if (identical(position, "LONG")) return("No next-open action; model is long/hold.")
  if (identical(position, "FLAT")) return("No next-open action; model is flat.")
  "No next-open action; position state unavailable."
}

g5_bridge_dual_advice_summary <- function(policy_results, operator_policy_by_symbol = NULL) {
  rows <- list()
  for (policy in names(policy_results)) {
    daily <- policy_results[[policy]]$daily
    book <- daily$book_summary
    if (!is.data.frame(book) || !nrow(book)) next
    for (i in seq_len(nrow(book))) {
      row <- book[i, , drop = FALSE]
      symbol <- as.character(row$symbol[[1L]])
      pending_action <- g5_bridge_pending_action_for_symbol(daily$pending_actions, symbol)
      operator_use <- if (!is.null(operator_policy_by_symbol) && symbol %in% names(operator_policy_by_symbol)) {
        identical(as.character(operator_policy_by_symbol[[symbol]]), policy)
      } else {
        FALSE
      }
      rows[[length(rows) + 1L]] <- data.frame(
        schema_version = g5_live_bridge_schema_version(),
        selection_policy = policy,
        selection_policy_label = as.character(daily$selection_policy_label),
        symbol = symbol,
        operator_declared_use = operator_use,
        as_of_date = as.Date(row$as_of_date[[1L]]),
        close = suppressWarnings(as.numeric(row$close[[1L]])),
        current_model_position = as.character(row$current_model_position[[1L]]),
        pending_action = pending_action,
        advice_text = g5_bridge_advice_text(as.character(row$current_model_position[[1L]]), pending_action),
        state_id = as.character(row$state_id[[1L]]),
        selected_strategy_family = as.character(row$selected_strategy_family[[1L]]),
        selected_strategy_spec_id = as.character(row$selected_strategy_spec_id[[1L]]),
        selected_signal_params = as.character(row$selected_signal_params[[1L]]),
        open_trade_strategy_spec_id = as.character(row$open_trade_strategy_spec_id[[1L]]),
        open_trade_signal_params = as.character(row$open_trade_signal_params[[1L]]),
        open_trade_entry_execution_date = as.Date(row$open_trade_entry_execution_date[[1L]]),
        authority_quarter_id = if ("authority_quarter_id" %in% names(row)) as.character(row$authority_quarter_id[[1L]]) else NA_character_,
        authority_role = if ("authority_role" %in% names(row)) as.character(row$authority_role[[1L]]) else NA_character_,
        stringsAsFactors = FALSE
      )
    }
  }
  if (length(rows)) g5_wfa_bind_rows_fill(rows) else data.frame()
}

g5_bridge_write_dual_contact_sheet <- function(policy_results, path, chart_lookback_days = 90L) {
  policies <- names(policy_results)
  symbols <- names(policy_results[[1L]]$daily$symbol_results)
  grDevices::png(path, width = 3200, height = 3200, res = 180)
  oldpar <- graphics::par(no.readonly = TRUE)
  on.exit({ graphics::par(oldpar); grDevices::dev.off() }, add = TRUE)
  graphics::par(mfrow = c(length(symbols), length(policies)), mar = c(3.6, 3.8, 2.7, 1))
  for (symbol in symbols) {
    for (policy in policies) {
      daily <- policy_results[[policy]]$daily
      chart_start_date <- as.Date(daily$as_of_date) - as.integer(chart_lookback_days)
      chart_replay <- g5_bridge_chart_replay(
        daily$symbol_results[[symbol]],
        chart_start_date = chart_start_date,
        chart_end_date = daily$as_of_date
      )
      g5_bridge_plot_panel(
        chart_replay,
        daily$symbol_results[[symbol]]$executions,
        daily$symbol_results[[symbol]]$pending_actions,
        daily$symbol_results[[symbol]]$trades,
        main = paste0(symbol, " - ", daily$selection_policy_label)
      )
    }
  }
  invisible(path)
}

g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)

as_of_timestamp <- arg_or_env("as_of", "GEN5_BRIDGE_DAILY_AS_OF_TIMESTAMP", env_or("GEN5_AS_OF_TIMESTAMP", ""))
if (!nzchar(as_of_timestamp)) {
  g5_stop("An explicit --as-of= timestamp or GEN5_BRIDGE_DAILY_AS_OF_TIMESTAMP is required.")
}
as_of_date <- as.Date(substr(as_of_timestamp, 1L, 10L))
if (is.na(as_of_date)) {
  g5_stop("--as-of must begin with a valid YYYY-MM-DD date.")
}
quarter_id <- toupper(arg_or_env("quarter", "GEN5_BRIDGE_QUARTER_ID", g5_bridge_quarter_id(as_of_date)))
refresh <- g5_parse_bool_env(arg_or_env("refresh", "GEN5_BRIDGE_REFRESH", "true"), default = TRUE)
continuity <- g5_parse_bool_env(arg_or_env("continuity", "GEN5_BRIDGE_CONTINUITY", "true"), default = TRUE)
warmup_days <- as.integer(arg_or_env("warmup_days", "GEN5_BRIDGE_WARMUP_DAYS", "420"))
if (is.na(warmup_days) || warmup_days < 60L) g5_stop("warmup_days must be an integer >= 60.")
min_train_state_rows <- as.integer(arg_or_env("min_train_state_rows", "GEN5_BRIDGE_MIN_TRAIN_STATE_ROWS", "20"))
if (is.na(min_train_state_rows) || min_train_state_rows < 1L) g5_stop("min_train_state_rows must be a positive integer.")

authority_dir <- arg_or_env("authority_dir", "GEN5_BRIDGE_AUTHORITY_DIR", g5_bridge_authority_dir(repo_root, quarter_id))
authority <- g5_bridge_read_authority(authority_dir, include_train_state_performance = TRUE)
contract <- authority$contract[1L, , drop = FALSE]
symbols <- g5_standardize_symbol(strsplit(contract$symbols[[1L]], ",", fixed = TRUE)[[1L]])
context_symbols <- if ("context_symbols" %in% names(contract) && nzchar(as.character(contract$context_symbols[[1L]]))) {
  unique(g5_standardize_symbol(strsplit(contract$context_symbols[[1L]], ",", fixed = TRUE)[[1L]]))
} else {
  symbols
}
default_feed <- if ("market_data_feed" %in% names(contract) && nzchar(as.character(contract$market_data_feed[[1L]]))) as.character(contract$market_data_feed[[1L]]) else as.character(cfg$feed)
feed <- arg_or_env("feed", "GEN5_BRIDGE_FEED", default_feed)
if (nzchar(feed)) cfg$feed <- feed
if (!identical(contract$quarter_id[[1L]], quarter_id)) {
  g5_stop("Requested quarter does not match frozen authority contract.")
}
if (as_of_date > as.Date(contract$live_end_date[[1L]])) {
  g5_stop("Frozen bridge authority is expired for this as-of date.")
}

previous_authority <- NULL
previous_authority_dir <- ""
if (continuity) {
  previous_quarter_id <- g5_bridge_previous_quarter_id(quarter_id)
  previous_authority_dir <- arg_or_env("previous_authority_dir", "GEN5_BRIDGE_PREVIOUS_AUTHORITY_DIR", g5_bridge_authority_dir(repo_root, previous_quarter_id))
  previous_authority <- g5_bridge_read_authority(previous_authority_dir, include_train_state_performance = TRUE)
}

query_start_date <- as.Date(contract$train_start_date[[1L]]) - warmup_days
if (!is.null(previous_authority)) {
  query_start_date <- min(query_start_date, as.Date(previous_authority$contract$train_start_date[[1L]]) - warmup_days)
}
query_end_date <- as_of_date
output_dir <- file.path(repo_root, "runs", "live_advice_bridge", "daily_dual", quarter_id, g5_bridge_safe_stamp(as_of_timestamp))

message("Gen5.1 dual-policy live-advice bridge daily runner")
message("Repository: ", repo_root)
message("Quarter: ", quarter_id)
message("Authority: ", authority_dir)
if (continuity) message("Previous authority: ", previous_authority_dir)
message("Symbols: ", paste(symbols, collapse = ", "))
message("As of: ", as_of_timestamp)
message("Feed: ", cfg$feed)
message("Query: ", query_start_date, " through ", query_end_date)
message("Refresh: ", refresh)
message("Continuity replay: ", continuity)
message("Output: ", output_dir)

result <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start_date,
  end_date = query_end_date,
  as_of_timestamp = as_of_timestamp,
  symbols = unique(c(symbols, context_symbols)),
  universe_name = paste0("live_bridge_dual_daily_", quarter_id),
  universe_roles = "bridge_context_universe",
  refresh = refresh,
  repo_root = repo_root
)
for (symbol in unique(c(symbols, context_symbols))) {
  g5_require_chartable_symbol(result, symbol = symbol, refresh = refresh)
}

policy_specs <- g5_bridge_dual_policy_specs()
operator_policy_by_symbol <- stats::setNames(rep("asset_state_direct_spec", length(symbols)), symbols)
operator_policy_by_symbol[["AMD"]] <- "pooled_family_asset_variant"
policy_results <- list()
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
query_paths <- g5_write_workbench_query_artifacts(result, output_dir = output_dir, prefix = "bridge_dual_daily_query")

for (i in seq_len(nrow(policy_specs))) {
  spec <- policy_specs[i, , drop = FALSE]
  policy <- as.character(spec$selection_policy[[1L]])
  label <- as.character(spec$policy_short_label[[1L]])
  current_policy_authority <- g5_bridge_apply_selection_policy(authority, policy, min_train_state_rows = min_train_state_rows)
  previous_policy_authority <- if (!is.null(previous_authority)) {
    g5_bridge_apply_selection_policy(previous_authority, policy, min_train_state_rows = min_train_state_rows)
  } else {
    NULL
  }
  daily <- if (continuity) {
    g5_bridge_run_daily_continuity_from_bars(
      result$bars,
      current_authority = current_policy_authority,
      previous_authority = previous_policy_authority,
      as_of_timestamp = result$resolved_session$as_of_timestamp
    )
  } else {
    g5_bridge_run_daily_from_bars(
      result$bars,
      authority = current_policy_authority,
      as_of_timestamp = result$resolved_session$as_of_timestamp
    )
  }
  daily <- g5_bridge_tag_daily_policy(daily, policy, label)
  policy_dir <- file.path(output_dir, as.character(spec$output_slug[[1L]]))
  policy_paths <- g5_bridge_write_daily_outputs(daily, policy_dir)
  policy_results[[policy]] <- list(spec = spec, daily = daily, paths = policy_paths, output_dir = policy_dir)
}

advice <- g5_bridge_dual_advice_summary(policy_results, operator_policy_by_symbol = operator_policy_by_symbol)
book <- g5_wfa_bind_rows_fill(lapply(policy_results, function(x) x$daily$book_summary))
pending <- g5_wfa_bind_rows_fill(lapply(policy_results, function(x) x$daily$pending_actions))
executions <- g5_wfa_bind_rows_fill(lapply(policy_results, function(x) x$daily$executions))
trades <- g5_wfa_bind_rows_fill(lapply(policy_results, function(x) x$daily$trades))
policy_pref <- data.frame(
  symbol = names(operator_policy_by_symbol),
  operator_declared_policy = unname(operator_policy_by_symbol),
  operator_declared_policy_label = policy_specs$policy_short_label[match(unname(operator_policy_by_symbol), policy_specs$selection_policy)],
  note = "Operator-declared temporary discretion rule: AMD under Gen4-style pooled-family; all other live-basket symbols under Gen5.1 direct-spec.",
  stringsAsFactors = FALSE
)

paths <- list(
  advice_summary_csv = file.path(output_dir, "dual_bridge_advice_summary.csv"),
  book_summary_csv = file.path(output_dir, "dual_bridge_book_summary.csv"),
  pending_actions_csv = file.path(output_dir, "dual_bridge_pending_actions.csv"),
  executions_csv = file.path(output_dir, "dual_bridge_executions.csv"),
  trades_csv = file.path(output_dir, "dual_bridge_trades.csv"),
  operator_policy_preference_csv = file.path(output_dir, "dual_bridge_operator_policy_preference.csv"),
  policy_taxonomy_csv = file.path(output_dir, "dual_bridge_policy_taxonomy.csv"),
  report_md = file.path(output_dir, "dual_bridge_daily_report.md"),
  contact_sheet_png = file.path(output_dir, "dual_bridge_contact_sheet.png")
)
g5_wfa_write_csv(advice, paths$advice_summary_csv)
g5_wfa_write_csv(book, paths$book_summary_csv)
g5_wfa_write_csv(pending, paths$pending_actions_csv)
g5_wfa_write_csv(executions, paths$executions_csv)
g5_wfa_write_csv(trades, paths$trades_csv)
g5_wfa_write_csv(policy_pref, paths$operator_policy_preference_csv)
g5_wfa_write_csv(policy_specs, paths$policy_taxonomy_csv)
g5_bridge_write_dual_contact_sheet(policy_results, paths$contact_sheet_png)

selected_lines <- if (nrow(advice)) {
  unlist(lapply(seq_len(nrow(advice)), function(i) {
    row <- advice[i, , drop = FALSE]
    marker <- if (isTRUE(row$operator_declared_use[[1L]])) " [operator-declared use]" else ""
    paste0(
      "- `", row$selection_policy_label[[1L]], "` / `", row$symbol[[1L]], "`", marker, ": `",
      row$current_model_position[[1L]], "`; ", row$advice_text[[1L]], "; selected `",
      row$selected_strategy_spec_id[[1L]], "`"
    )
  }))
} else {
  "_No advice rows written._"
}

report <- c(
  paste0("# Dual-Policy Live Advice Bridge Daily Packet: ", quarter_id),
  "",
  "## Purpose",
  "",
  "This packet runs the temporary live-advice bridge across both selection-policy lanes so the operator can inspect Gen4-style and Gen5.1-style signals side by side. It is advice-only and does not place orders.",
  "",
  paste0("- As of timestamp: `", as_of_timestamp, "`"),
  paste0("- Latest replay date: `", as.Date(max(as.Date(result$bars$session_date), na.rm = TRUE)), "`"),
  paste0("- Feed: `", cfg$feed, "`"),
  "- Gen4-style lane: `pooled_family_asset_variant`",
  "- Gen5.1 lane: `asset_state_direct_spec`",
  "- Temporary operator-declared discretion rule recorded in this packet: `AMD` under Gen4-style pooled-family; `NVDA,PLTR,TSLA,SOFI` under Gen5.1 direct-spec.",
  "",
  "## Text Advice",
  "",
  selected_lines,
  "",
  "## Artifacts",
  "",
  "- `dual_bridge_advice_summary.csv`",
  "- `dual_bridge_operator_policy_preference.csv`",
  "- `dual_bridge_contact_sheet.png`",
  "- `gen4_pooled_family/bridge_contact_sheet.png`",
  "- `gen5_1_direct_spec/bridge_contact_sheet.png`",
  "- per-symbol charts inside each policy folder",
  "",
  "## Guardrails",
  "",
  "- This is a temporary continuity surface, not production execution.",
  "- The policy labels describe selection mechanics only; they are not allocation approval.",
  "- Manual trade decisions remain operator decisions."
)
writeLines(report, paths$report_md, useBytes = TRUE)

message("")
message("Dual-policy advice summary:")
print(advice[, intersect(c("selection_policy_label", "symbol", "operator_declared_use", "current_model_position", "pending_action", "advice_text", "selected_strategy_spec_id"), names(advice)), drop = FALSE], row.names = FALSE)
message("")
message("Dual daily artifacts written:")
print(as.data.frame(paths), row.names = FALSE)
message("")
message("Query artifacts written:")
print(as.data.frame(query_paths), row.names = FALSE)
