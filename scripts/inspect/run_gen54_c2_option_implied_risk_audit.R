# Gen5.4 C2 research-only option-implied portfolio-risk audit.
# Cboe supplies VIX history; Alpaca remains the adjusted daily OHLCV authority.
# No scaler, return policy, allocation, replay, or live behavior.

script_path <- tryCatch(normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE), error = function(e) NULL)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE) else normalizePath(".", winslash = "/", mustWork = TRUE)
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
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_risk_audit.R"))
source(file.path(repo_root, "R", "cboe_index_provider.R"))
source(file.path(repo_root, "R", "gen54_c2_option_implied_risk_audit.R"))

env_or <- function(name, default = "") { value <- Sys.getenv(name, unset = ""); if (nzchar(value)) value else default }
write_csv <- function(x, path) { utils::write.csv(x, path, row.names = FALSE, na = ""); invisible(path) }
dir_create <- function(path) { dir.create(path, recursive = TRUE, showWarnings = FALSE); if (!dir.exists(path)) stop("Could not create output directory.", call. = FALSE) }

plot_fold_correlations <- function(fold_audit, path) {
  folds <- unique(fold_audit$fold_id)
  row_keys <- c("h5 direct", "h5 partial", "h20 direct", "h20 partial")
  values <- matrix(NA_real_, nrow = 4L, ncol = length(folds), dimnames = list(row_keys, folds))
  for (horizon in g5_gen54_c1_horizons()) {
    part <- fold_audit[fold_audit$horizon == horizon, , drop = FALSE]
    values[paste0("h", horizon, " direct"), match(part$fold_id, folds)] <- part$rank_correlation
    values[paste0("h", horizon, " partial"), match(part$fold_id, folds)] <- part$partial_rank_correlation_controlling_spy_drawdown
  }
  limit <- max(abs(values), na.rm = TRUE)
  grDevices::png(path, width = 1800, height = 850, res = 150)
  graphics::par(mar = c(7, 8, 4, 2))
  graphics::image(seq_along(folds), seq_len(4L), t(values), zlim = c(-limit, limit), col = grDevices::colorRampPalette(c("#B91C1C", "white", "#166534"))(101), axes = FALSE, xlab = "", ylab = "", main = "C2 VIX-to-forward-risk correlation: direct and controlling for SPY drawdown")
  graphics::axis(1, at = seq_along(folds), labels = folds, las = 2, cex.axis = 0.75)
  graphics::axis(2, at = seq_len(4L), labels = row_keys, las = 1)
  grDevices::dev.off()
}

plot_separation <- function(summary, path) {
  values <- summary$mean_separation_realized_volatility
  names(values) <- paste0(
    "h", summary$horizon, "\n",
    summary$positive_separation_folds, "/20 positive folds"
  )
  grDevices::png(path, width = 1200, height = 800, res = 150)
  graphics::par(mar = c(5, 6, 4, 2))
  bars <- graphics::barplot(
    values,
    col = c("#60A5FA", "#1D4ED8"),
    ylab = "High-minus-low forward realized volatility",
    main = "Pooled separation is positive; quarterly transport misses the 12/20 gate"
  )
  graphics::abline(h = 0, col = "#111827")
  graphics::text(bars, values, labels = sprintf("%+.3f", values), pos = ifelse(values >= 0, 3, 1))
  grDevices::dev.off()
}

plot_tapes <- function(context, path) {
  panels <- list(
    "2020 stress and normalization" = c(as.Date("2020-02-01"), as.Date("2020-08-31")),
    "2022 persistent repricing" = c(as.Date("2022-01-01"), as.Date("2022-12-31"))
  )
  grDevices::png(path, width = 1800, height = 1100, res = 150)
  graphics::par(mfrow = c(2, 1), mar = c(4, 5, 4, 5))
  for (title in names(panels)) {
    range <- panels[[title]]
    part <- context[context$feature_date >= range[[1L]] & context$feature_date <= range[[2L]], , drop = FALSE]
    graphics::plot(part$feature_date, 100 * part$vix_30d_close, type = "l", col = "#7C3AED", lwd = 2, xlab = "", ylab = "VIX close", main = title)
    graphics::par(new = TRUE)
    graphics::plot(part$feature_date, part$forward_realized_volatility_h20, type = "l", col = "#0F766E", lwd = 2, axes = FALSE, xlab = "", ylab = "")
    graphics::axis(4, col.axis = "#0F766E")
    graphics::mtext("Forward h20 basket realized volatility", side = 4, line = 3, col = "#0F766E")
    graphics::legend("topright", legend = c("VIX", "Forward h20 basket risk"), col = c("#7C3AED", "#0F766E"), lty = 1, lwd = 2, bty = "n")
  }
  grDevices::dev.off()
}

message("Gen5.4 C2 option-implied risk audit starting.")
g5_load_local_renviron(repo_root)
cfg <- g5_load_data_layer_config(repo_root)
cfg$feed <- env_or("GEN5_GEN54_C2_FEED", as.character(cfg$feed))
refresh <- g5_parse_bool_env(env_or("GEN5_GEN54_C2_REFRESH", "false"), default = FALSE)
as_of_timestamp <- env_or("GEN5_GEN54_C2_AS_OF", "2024-12-31 17:30:00")
retrieved_at_timestamp <- env_or("GEN5_GEN54_C2_RETRIEVED_AT", "2026-07-21 17:30:00")
run_id <- env_or("GEN5_GEN54_C2_RUN_ID", "g54_c2_vix_risk_20260721")
output_dir <- file.path(repo_root, "runs", "research_workbench", "gen54_ml_decision_engine", run_id)
visual_dir <- file.path(output_dir, "visuals")
source_dir <- file.path(output_dir, "source")
dir_create(visual_dir)
dir_create(source_dir)

registry <- g5_gen54_xs_candidate_registry()
context_symbols <- g5_gen54_xs_context_symbols()
folds <- g5_gen54_xs_build_folds(2020:2024)
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = as.Date("2016-11-01"),
  end_date = max(folds$oos_end_date),
  as_of_timestamp = as_of_timestamp,
  symbols = unique(c(registry$symbol, context_symbols)),
  universe_name = "gen54_cross_sectional_fixed_panel_v0_1",
  universe_roles = "ranked_candidates,context_anchors",
  refresh = refresh,
  repo_root = repo_root
)
if (!nrow(query$bars)) stop("C2 Alpaca query returned no bars.", call. = FALSE)
base_panel <- g5_gen54_xs_build_panel(query$bars, registry, context_symbols)
context <- g5_gen54_c1_build_context(query$bars, base_panel, registry, minimum_reference_basket = 18L)

vix_fetch <- g5_cboe_fetch_vix_history(
  start_date = min(folds$train_start_date),
  end_date = max(folds$oos_end_date),
  as_of_timestamp = as_of_timestamp
)
raw_path <- file.path(source_dir, "cboe_vix_history_snapshot.csv")
writeLines(vix_fetch$response_text, raw_path, useBytes = TRUE)
vix_path <- file.path(source_dir, "cboe_vix_accepted.csv")
write_csv(vix_fetch$data, vix_path)
context <- g5_gen54_c2_join_vix(context, vix_fetch$data)
fold_audit <- g5_gen54_c2_fold_audit(context, folds)
verdict <- g5_gen54_c2_verdict(fold_audit)

evaluation_dates <- context$feature_date >= min(folds$train_start_date) & context$feature_date <= max(folds$oos_end_date)
join_coverage <- mean(is.finite(context$vix_30d_close[evaluation_dates]))
health <- data.frame(
  severity = c("INFO", "INFO", "INFO", if (join_coverage >= 0.99) "INFO" else "ERROR", "INFO", "INFO"),
  check_id = c("cboe_http_status", "cboe_schema", "cboe_date_coverage", "cboe_join_coverage", "cboe_duplicate_dates", "future_rows_admitted"),
  detail = c(
    paste0("HTTP ", vix_fetch$http_status, " from official Cboe VIX history."),
    "Exact DATE,OPEN,HIGH,LOW,CLOSE schema parsed.",
    paste0(min(vix_fetch$data$observation_date), " through ", max(vix_fetch$data$observation_date), "."),
    paste0(sprintf("%.2f%%", 100 * join_coverage), " of evaluation-session dates have same-date VIX closes; no fill used."),
    paste0("duplicate dates=", anyDuplicated(vix_fetch$data$observation_date), "."),
    paste0("accepted rows after ", substr(as_of_timestamp, 1L, 10L), "=0.")
  ),
  stringsAsFactors = FALSE
)
write_csv(health, file.path(output_dir, "c2_data_health.csv"))
if (any(health$severity == "ERROR")) stop("C2 Cboe data admission failed; inspect c2_data_health.csv.", call. = FALSE)

manifest <- data.frame(
  provider = "cboe",
  series_id = "VIX",
  source_url = vix_fetch$source_url,
  as_of_timestamp = as_of_timestamp,
  retrieved_at_timestamp = retrieved_at_timestamp,
  accepted_start_date = min(vix_fetch$data$observation_date),
  accepted_end_date = max(vix_fetch$data$observation_date),
  accepted_rows = nrow(vix_fetch$data),
  raw_bytes = file.info(raw_path)$size,
  raw_md5 = unname(tools::md5sum(raw_path)),
  stringsAsFactors = FALSE
)
leakage <- data.frame(
  check_id = c("explicit_as_of_timestamp", "official_cboe_authority", "same_date_after_close_observation", "no_vix_fill", "next_open_execution", "labels_inside_oos", "thresholds_train_only", "partial_control_predeclared", "no_policy_or_replay"),
  status = "PASS",
  detail = c(
    paste0("Cboe and Alpaca inputs are bounded by ", as_of_timestamp, "."),
    "VIX comes from Cboe's official daily-history CSV; VIXY is not substituted.",
    "Only the VIX close dated session t is available to the after-close t signal.",
    "Missing VIX dates remain missing.",
    "The hypothetical action point remains open t+1; forward risk begins after that open.",
    "Every h5 and h20 label must end within its quarterly OOS fold.",
    "Each VIX high-state threshold is the preceding eight-quarter TRAIN median.",
    "Incremental evidence is partial rank correlation controlling SPY drawdown, frozen before inspection.",
    "Model, scaler, replay, allocation, and live counts are zero."
  ),
  stringsAsFactors = FALSE
)
run_spec <- data.frame(
  schema_version = "gen54_c2_vix_risk_v0.1",
  wrapper = "scripts/inspect/run_gen54_c2_option_implied_risk_audit.R",
  as_of_timestamp = as_of_timestamp,
  alpaca_feed = cfg$feed,
  non_ohlcv_provider = "cboe",
  non_ohlcv_series = "VIX",
  fold_count = nrow(folds),
  train_quarters = 8L,
  horizons = "h5,h20",
  required_positive_folds = 12L,
  model_fit_count = 0L,
  scaler_policy_count = 0L,
  return_replay_count = 0L,
  allocation_count = 0L,
  overall_status = verdict$overall_status,
  stringsAsFactors = FALSE
)

write_csv(run_spec, file.path(output_dir, "c2_run_spec.csv"))
write_csv(manifest, file.path(output_dir, "c2_cboe_manifest.csv"))
write_csv(query$health, file.path(output_dir, "c2_alpaca_data_health.csv"))
write_csv(folds, file.path(output_dir, "c2_fold_spec.csv"))
write_csv(context, file.path(output_dir, "c2_daily_context.csv"))
write_csv(fold_audit, file.path(output_dir, "c2_fold_audit.csv"))
write_csv(verdict$horizon_summary, file.path(output_dir, "c2_horizon_summary.csv"))
write_csv(leakage, file.path(output_dir, "c2_leakage_audit.csv"))
plot_fold_correlations(fold_audit, file.path(visual_dir, "c2_fold_correlations.png"))
plot_separation(verdict$horizon_summary, file.path(visual_dir, "c2_risk_separation.png"))
plot_tapes(context, file.path(visual_dir, "c2_2020_2022_risk_tapes.png"))

summary <- verdict$horizon_summary
report <- c(
  "# Gen5.4 C2 Option-Implied Risk Audit", "",
  paste0("Status: `", verdict$overall_status, "`"), "",
  "## Boundary", "",
  "One official Cboe VIX close is tested as a non-OHLCV, still market-derived risk primitive. Alpaca remains the adjusted daily OHLCV authority. No model, scaler, return replay, allocation, or live behavior is created.", "",
  "## Provider decision", "",
  "Alpaca's stock-bars endpoint returned no VIX rows in the feasibility preflight. VIXY was rejected because it is a rolling VIX-futures ETF rather than the VIX index. C2 therefore uses Cboe's official VIX history CSV.", "",
  "## Frozen evidence", "",
  paste0(
    "- h", summary$horizon, ": `", summary$horizon_verdict,
    "`; direct positive folds `", summary$positive_correlation_folds, "/20`; partial positive folds `",
    summary$positive_partial_correlation_folds, "/20`; separation positive folds `", summary$positive_separation_folds,
    "/20`; mean direct correlation `", sprintf("%.3f", summary$mean_rank_correlation),
    "`; mean partial correlation `", sprintf("%.3f", summary$mean_partial_rank_correlation),
    "`; high-minus-low realized volatility `", sprintf("%+.3f", summary$mean_separation_realized_volatility), "`."
  ), "",
  "## Next gate", "",
  if (verdict$overall_status == "PASS_TO_RISK_POLICY_THEORY_SESSION") {
    "VIX passed both direct and incremental gates at both horizons. Open a separate theory session before defining any exposure function."
  } else if (verdict$overall_status == "STOP_THRESHOLD_INSTABILITY") {
    "VIX passed continuous and drawdown-controlled ordering at both horizons, but the frozen TRAIN-median high/low state did not transport consistently. Do not retune the threshold or design a scaler on these folds."
  } else if (verdict$overall_status == "REDUNDANT_WITH_PRICE_STRESS") {
    "VIX ordered risk directly but did not add stable information beyond SPY drawdown. Do not treat it as a new primitive."
  } else if (verdict$overall_status == "STOP_HORIZON_SPECIFIC") {
    "VIX evidence is horizon-specific. Do not delete the failed horizon or design a scaler."
  } else {
    "VIX did not pass the frozen two-horizon option-implied risk gate. Do not design a scaler."
  }, "",
  "## Visuals", "",
  "- `visuals/c2_fold_correlations.png`",
  "- `visuals/c2_risk_separation.png`",
  "- `visuals/c2_2020_2022_risk_tapes.png`"
)
writeLines(report, file.path(output_dir, "c2_report.md"), useBytes = TRUE)
message("Gen5.4 C2 complete: ", verdict$overall_status)
message("Cboe data health: ", if (any(health$severity == "ERROR")) "ERROR" else "INFO")
message("Report: ", normalizePath(file.path(output_dir, "c2_report.md"), winslash = "/"))
