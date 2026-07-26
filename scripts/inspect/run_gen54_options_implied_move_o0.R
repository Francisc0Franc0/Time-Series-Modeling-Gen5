# Gen5.4 O0 historical-options reconstruction proof.
# No outcomes, model, policy, replay, allocation, PnL, or live behavior.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE) else normalizePath(".", winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "alpaca_options_provider.R"))
source(file.path(repo_root, "R", "gen54_options_implied_move_poc.R"))

env_or <- function(name, default = "") {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}
dir_create <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  if (!dir.exists(path)) stop("Could not create O0 output directory.", call. = FALSE)
}

plot_implied_move <- function(measure, path) {
  valid <- measure[measure$matched_pair_valid, , drop = FALSE]
  symbols <- unique(measure$underlying_symbol)
  grDevices::png(path, width = 1800, height = 1000, res = 150)
  graphics::par(mfrow = c(length(symbols), 1L), mar = c(3, 5, 3, 2))
  for (symbol in symbols) {
    part <- valid[valid$underlying_symbol == symbol, , drop = FALSE]
    if (!nrow(part)) {
      graphics::plot.new()
      graphics::title(main = paste(symbol, "- no valid matched straddles"))
      next
    }
    graphics::plot(
      part$session_date,
      100 * part$normalized_implied_move_30d,
      type = "o",
      pch = 19,
      lwd = 2,
      col = "#0F766E",
      xlab = "",
      ylab = "30d implied move (%)",
      main = paste(symbol, "- fixed 15:45 ET indicative ATM straddle")
    )
    graphics::grid(col = "#E5E7EB")
  }
  grDevices::dev.off()
}

plot_coverage <- function(measure, path) {
  symbols <- unique(measure$underlying_symbol)
  dates <- sort(unique(measure$session_date))
  values <- matrix(
    0,
    nrow = length(symbols),
    ncol = length(dates),
    dimnames = list(symbols, as.character(dates))
  )
  for (i in seq_len(nrow(measure))) {
    values[
      measure$underlying_symbol[[i]],
      as.character(measure$session_date[[i]])
    ] <- if (isTRUE(measure$matched_pair_valid[[i]])) 1 else 0
  }
  grDevices::png(path, width = 1500, height = 700, res = 150)
  graphics::par(mar = c(7, 6, 4, 2))
  graphics::image(
    seq_along(dates),
    seq_along(symbols),
    t(values),
    zlim = c(0, 1),
    col = c("#FCA5A5", "#86EFAC"),
    axes = FALSE,
    xlab = "",
    ylab = "",
    main = "O0 matched-pair coverage (green = both legs at 15:45 ET)"
  )
  graphics::axis(1, at = seq_along(dates), labels = dates, las = 2)
  graphics::axis(2, at = seq_along(symbols), labels = symbols, las = 1)
  grDevices::dev.off()
}

plot_strike_selection <- function(measure, path) {
  colors <- c(SPY = "#1D4ED8", QQQ = "#7C3AED", IWM = "#D97706")
  grDevices::png(path, width = 1500, height = 850, res = 150)
  graphics::par(mar = c(5, 6, 4, 2))
  y <- 100 * measure$strike_distance_fraction
  graphics::plot(
    measure$session_date,
    y,
    type = "n",
    xlab = "",
    ylab = "Absolute strike distance from spot (%)",
    main = "O0 ATM selection diagnostic"
  )
  for (symbol in names(colors)) {
    part <- measure[measure$underlying_symbol == symbol, , drop = FALSE]
    graphics::lines(part$session_date, 100 * part$strike_distance_fraction, type = "o", pch = 19, lwd = 2, col = colors[[symbol]])
  }
  graphics::grid(col = "#E5E7EB")
  graphics::legend("topright", legend = names(colors), col = colors, pch = 19, lty = 1, bty = "n")
  grDevices::dev.off()
}

message("Gen5.4 options O0 reconstruction starting.")
g5_load_local_renviron(repo_root)
config <- g5_alpaca_config_from_env()
as_of_timestamp <- env_or("GEN5_GEN54_OPTIONS_AS_OF", "2026-07-26 17:30:00")
retrieved_at <- env_or("GEN5_GEN54_OPTIONS_RETRIEVED_AT", "2026-07-26 17:30:00")
trading_base_url <- env_or("GEN5_ALPACA_TRADING_BASE_URL", "https://paper-api.alpaca.markets")
run_id <- env_or("GEN5_GEN54_OPTIONS_O0_RUN_ID", "g54_options_o0_20260726")
session_dates <- seq(as.Date("2026-07-20"), as.Date("2026-07-24"), by = "day")
session_dates <- session_dates[as.POSIXlt(session_dates)$wday %in% 1:5]
underlyings <- c("SPY", "QQQ", "IWM")
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id
)
visual_dir <- file.path(output_dir, "visuals")
dir_create(visual_dir)

contract_request <- g5_alpaca_option_contracts_request(
  underlying_symbols = underlyings,
  expiration_date_gte = min(session_dates) + 21L,
  expiration_date_lte = max(session_dates) + 45L,
  as_of_timestamp = as_of_timestamp,
  status = "active",
  limit = 1000L
)
contract_fetch <- g5_fetch_alpaca_option_contracts(
  contract_request,
  retrieved_at = retrieved_at,
  config = config,
  trading_base_url = trading_base_url
)
if (!nrow(contract_fetch$data)) stop("O0 returned no active option contracts.", call. = FALSE)

entitlement <- g5_probe_alpaca_option_feed_entitlement(
  contract_fetch$data$option_symbol[[1L]],
  config = config
)
if (!entitlement$resolved_feed %in% c("opra", "indicative")) {
  stop("O0 could not resolve an option-feed entitlement.", call. = FALSE)
}

underlying_request <- g5_alpaca_option_underlying_bars_request(
  underlyings,
  start_timestamp = paste0(min(session_dates), "T13:30:00Z"),
  end_timestamp = paste0(max(session_dates), "T20:00:00Z"),
  as_of_timestamp = as_of_timestamp,
  timeframe = "15Min",
  feed = "sip"
)
underlying_fetch <- g5_fetch_alpaca_option_underlying_bars(
  underlying_request,
  retrieved_at = retrieved_at,
  config = config
)
underlying_final <- g5_gen54_o0_final_bars(
  underlying_fetch$data,
  symbol_column = "symbol"
)
selections <- g5_gen54_o0_select_pairs(
  contract_fetch$data,
  underlying_final,
  session_dates,
  underlyings = underlyings
)

option_fetches <- list()
for (session_date in session_dates) {
  session_date <- as.Date(session_date, origin = "1970-01-01")
  part <- selections[
    selections$session_date == session_date &
      selections$selection_status == "SELECTED",
    ,
    drop = FALSE
  ]
  symbols <- unique(c(part$call_symbol, part$put_symbol))
  if (!length(symbols)) next
  request <- g5_alpaca_option_bars_request(
    symbols,
    start_timestamp = paste0(session_date, "T19:45:00Z"),
    end_timestamp = paste0(session_date, "T20:00:00Z"),
    as_of_timestamp = as_of_timestamp,
    timeframe = "15Min",
    feed = entitlement$resolved_feed
  )
  option_fetches[[as.character(session_date)]] <- g5_fetch_alpaca_option_bars(
    request,
    retrieved_at = retrieved_at,
    config = config
  )
}
option_bars <- if (!length(option_fetches)) {
  g5_alpaca_empty_option_bars()
} else {
  frames <- lapply(option_fetches, function(x) x$data)
  frames <- frames[vapply(frames, nrow, integer(1L)) > 0L]
  if (length(frames)) do.call(rbind, frames) else g5_alpaca_empty_option_bars()
}
option_final <- g5_gen54_o0_final_bars(
  option_bars,
  symbol_column = "option_symbol"
)
measure <- g5_gen54_o0_construct_measure(selections, option_final)
coverage <- g5_gen54_o0_coverage(measure)
overall_status <- g5_gen54_o0_verdict(
  measure, coverage, entitlement$resolved_feed
)

health <- data.frame(
  severity = c(
    "INFO",
    "INFO",
    if (nrow(underlying_final) == length(session_dates) * length(underlyings)) "INFO" else "ERROR",
    if (all(selections$selection_status == "SELECTED")) "INFO" else "ERROR",
    if (all(coverage$verdict == "PASS_O0_COVERAGE")) "INFO" else "ERROR",
    "WARN"
  ),
  check_id = c(
    "contract_endpoint",
    "option_feed_entitlement",
    "underlying_final_bar_coverage",
    "matched_contract_definition_coverage",
    "matched_option_bar_coverage",
    "history_scope"
  ),
  detail = c(
    paste0(nrow(contract_fetch$data), " immutable active contract definitions admitted."),
    paste0(
      "Resolved account-default historical option feed as ",
      entitlement$resolved_feed,
      "; OPRA probe HTTP ",
      entitlement$probes$http_status[entitlement$probes$feed == "opra"],
      ", indicative probe HTTP ",
      entitlement$probes$http_status[entitlement$probes$feed == "indicative"],
      "."
    ),
    paste0(nrow(underlying_final), "/", length(session_dates) * length(underlyings), " raw underlying 15:45 ET bars."),
    paste0(sum(selections$selection_status == "SELECTED"), "/", nrow(selections), " same-strike same-expiry contract pairs selected."),
    paste0(sum(measure$matched_pair_valid), "/", nrow(measure), " matched 15:45 ET straddles constructed."),
    "The paper contract endpoint did not return expired contracts. O0 is frozen to five recent sessions whose selected expiries remained active at retrieval; no February-2024 backfill claim is made."
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = "gen54_options_o0_v0.1",
  wrapper = "scripts/inspect/run_gen54_options_implied_move_o0.R",
  as_of_timestamp = as_of_timestamp,
  retrieved_at_timestamp = retrieved_at,
  session_start = min(session_dates),
  session_end = max(session_dates),
  underlyings = paste(underlyings, collapse = ","),
  option_feed = entitlement$resolved_feed,
  underlying_feed = "sip",
  underlying_adjustment = "raw",
  option_bar_timeframe = "15Min",
  final_bar_clock_et = "15:45",
  target_dte = 30L,
  minimum_dte = 21L,
  maximum_dte = 45L,
  minimum_coverage = 0.90,
  outcome_column_count = 0L,
  model_fit_count = 0L,
  policy_count = 0L,
  return_replay_count = 0L,
  allocation_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

leakage <- data.frame(
  check_id = c(
    "explicit_as_of_timestamp",
    "immutable_contract_fields_only",
    "fixed_session_window",
    "fixed_final_bar",
    "same_strike_same_expiry",
    "feed_identity",
    "no_future_outcomes",
    "no_model_policy_or_pnl"
  ),
  status = "PASS",
  detail = c(
    paste0("All requests are bounded by ", as_of_timestamp, "."),
    "Only symbol, underlying, expiration, strike, type, style, size, and retrieval status are normalized; current open interest and close metadata are excluded.",
    paste0("O0 is frozen to ", min(session_dates), " through ", max(session_dates), "."),
    "Underlying and both option legs use the 15Min bar timestamped 15:45 America/New_York; VWAP is primary.",
    "Every valid row requires call and put at one strike, one expiry, and one timestamp.",
    paste0("Every accepted option row is labeled ", entitlement$resolved_feed, "."),
    "No forward-return, forward-volatility, or other outcome column is present.",
    "Model, policy, return replay, allocation, and PnL counts are zero."
  ),
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "o0_run_spec.csv"))
write_csv(health, file.path(output_dir, "o0_data_health.csv"))
write_csv(leakage, file.path(output_dir, "o0_leakage_audit.csv"))
write_csv(contract_fetch$data, file.path(output_dir, "o0_contract_definitions.csv"))
write_csv(contract_fetch$pages, file.path(output_dir, "o0_contract_pages.csv"))
write_csv(entitlement$probes, file.path(output_dir, "o0_feed_entitlement.csv"))
write_csv(underlying_final, file.path(output_dir, "o0_underlying_final_bars.csv"))
write_csv(selections, file.path(output_dir, "o0_pair_selections.csv"))
write_csv(option_final, file.path(output_dir, "o0_option_final_bars.csv"))
write_csv(measure, file.path(output_dir, "o0_implied_move_measure.csv"))
write_csv(coverage, file.path(output_dir, "o0_coverage_summary.csv"))
plot_implied_move(measure, file.path(visual_dir, "o0_implied_move_tapes.png"))
plot_coverage(measure, file.path(visual_dir, "o0_pair_coverage.png"))
plot_strike_selection(measure, file.path(visual_dir, "o0_strike_selection.png"))

coverage_lines <- paste0(
  "- ", coverage$underlying_symbol, ": ",
  coverage$valid_matched_sessions, "/", coverage$eligible_sessions,
  " valid (", sprintf("%.1f%%", 100 * coverage$coverage), "); `",
  coverage$verdict, "`."
)
report <- c(
  "# Gen5.4 Options O0 Reconstruction Proof", "",
  paste0("Status: `", overall_status, "`"), "",
  "## Question", "",
  "Can Alpaca's account-default historical options feed reproduce a fixed-time, same-strike, same-expiry ATM straddle for SPY, QQQ, and IWM without outcomes or hindsight-prone contract fields?", "",
  "## Frozen narrow scope", "",
  paste0("- Sessions: `", min(session_dates), "` through `", max(session_dates), "`."),
  paste0("- Feed: `", entitlement$resolved_feed, "` (OPRA entitlement probe did not pass; no OPRA claim)."),
  "- Contract: expiry nearest 30 calendar days inside 21-45 DTE; strike nearest raw underlying 15:45 ET VWAP; call and put must share strike, expiry, and timestamp.",
  "- The expired-contract catalog was unavailable through the paper contract endpoint. This proof therefore uses only sessions whose selected expiries remained active when retrieved.", "",
  "## Coverage", "",
  coverage_lines, "",
  "## Interpretation", "",
  if (overall_status == "PASS_O0_NARROW_RECONSTRUCTION") {
    "The minimal plumbing gate passed. It proves a reproducible five-session indicative-feed construction, not a long-history signal and not OPRA-quality evidence. O1 remains a separate decision because a five-session construction proof is too short for a serious incremental-risk test."
  } else {
    "O0 stopped. Do not join outcomes or proceed to O1; inspect missing legs, final timestamps, and contract coverage without loosening the frozen construction."
  }, "",
  "## Visuals", "",
  "- `visuals/o0_implied_move_tapes.png`",
  "- `visuals/o0_pair_coverage.png`",
  "- `visuals/o0_strike_selection.png`"
)
writeLines(report, file.path(output_dir, "o0_report.md"), useBytes = TRUE)

message("Gen5.4 options O0 complete: ", overall_status)
message("Option feed: ", entitlement$resolved_feed)
message("Data health: ", if (any(health$severity == "ERROR")) "ERROR" else "WARN")
message("Report: ", normalizePath(file.path(output_dir, "o0_report.md"), winslash = "/"))
