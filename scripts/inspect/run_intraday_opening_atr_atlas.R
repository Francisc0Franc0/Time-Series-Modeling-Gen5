# Replicate the NVDA opening-tail / prior-day ATR mechanism across the frozen
# 26-asset intraday registry and through 2025. NVDA itself is deliberately
# absent, preserving its 2024+ single-asset confirmation period.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = FALSE)
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

local_lib <- file.path(repo_root, ".codex_r_libs")
if (dir.exists(local_lib)) .libPaths(c(local_lib, .libPaths()))
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_opening_atr_atlas.R"))

contract <- ioaa_validate_contract()
registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries",
  "gen5_intraday_momentum_poc_registry.csv"
)
registry_full <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
registry <- ioaa_validate_registry(registry_full, contract)
cache_dir <- file.path(repo_root, "data_cache", "alpaca_intraday_30min")
run_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "intraday_opening_atr_atlas_20260901"
)
visual_dir <- file.path(run_dir, "visuals")
dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

# Only the two missing completed calendar years are eligible for refresh.
refresh_years <- 2024:2025
config <- g5_alpaca_config_from_env()
for (year in refresh_years) {
  year_path <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d.rds", year))
  if (file.exists(year_path)) next
  g5_alpaca_require_credentials(config)
  if (!identical(config$feed, "sip")) config$feed <- "sip"
  message("Fetching frozen 26-asset Alpaca SIP 30Min year ", year, " ...")
  groups <- split(contract$expected_symbols, ceiling(seq_along(contract$expected_symbols) / 4L))
  group_bars <- vector("list", length(groups))
  for (group_i in seq_along(groups)) {
    group_path <- file.path(
      cache_dir,
      sprintf("intraday_30min_sip_all_%d_group_%02d.rds", year, group_i)
    )
    if (file.exists(group_path)) {
      group_bars[[group_i]] <- readRDS(group_path)
      status <- "CACHE_HIT"
    } else {
      request <- imom30_request(
        groups[[group_i]], as.Date(sprintf("%d-01-01", year)),
        as.Date(sprintf("%d-12-31", year)), contract$as_of_timestamp
      )
      group_bars[[group_i]] <- imom30_fetch(request, config)
      saveRDS(group_bars[[group_i]], group_path)
      status <- "FETCHED"
    }
    message("  group ", group_i, "/", length(groups), " ", status,
            " rows=", nrow(group_bars[[group_i]]))
  }
  bars_year <- do.call(rbind, group_bars)
  bars_year <- bars_year[order(bars_year$symbol, bars_year$timestamp_utc), , drop = FALSE]
  saveRDS(bars_year, year_path)
  message(year, " complete rows=", nrow(bars_year))
}

years <- 2017:2025
cache_paths <- file.path(cache_dir, sprintf("intraday_30min_sip_all_%d.rds", years))
if (!all(file.exists(cache_paths))) {
  stop("Required 2017-2025 adjusted SIP cache is incomplete: ",
       paste(cache_paths[!file.exists(cache_paths)], collapse = ", "), call. = FALSE)
}
chunks <- lapply(cache_paths, readRDS)
data_health <- do.call(rbind, Map(function(x, year) data.frame(
  year = year, rows = nrow(x), symbols = length(unique(x$symbol)),
  first_session = as.character(min(as.Date(x$session_date))),
  last_session = as.character(max(as.Date(x$session_date))),
  stringsAsFactors = FALSE
), chunks, years))
bars <- do.call(rbind, chunks)
bars <- bars[!duplicated(bars[c("symbol", "timestamp_utc")]), , drop = FALSE]
bars <- imom30_apply_rth_calendar(bars)
bars <- imom30_apply_archive_exclusions(bars)
bars <- bars[order(bars$symbol, bars$timestamp_utc), , drop = FALSE]

study <- ioaa_build_study(bars, registry, contract)
eligible_assets <- study$asset_summary[study$asset_summary$eligible, , drop = FALSE]
pooled_low <- study$pooled_state_summary[
  study$pooled_state_summary$atr_group == "LOW_MEDIUM", , drop = FALSE
]
pooled_high <- study$pooled_state_summary[
  study$pooled_state_summary$atr_group == "HIGH", , drop = FALSE
]

construction_checks <- data.frame(
  check_id = c(
    "preexisting_registry_exact", "nvda_confirmation_untouched",
    "all_completed_years_present", "provider_contract_exact",
    "analysis_stops_at_2025", "causal_opening_thresholds",
    "causal_prior_day_atr_state", "opening_and_remainder_prices_reproduce",
    "unique_asset_sessions", "all_three_eras_present"
  ),
  passed = c(
    identical(registry$symbol, contract$expected_symbols),
    !contract$excluded_symbol %in% unique(bars$symbol),
    identical(data_health$year, years) && all(data_health$symbols == 26L),
    all(bars$provider == "alpaca" & bars$feed == "sip" &
          bars$timeframe == "30Min" & bars$adjustment == "all"),
    max(study$sessions$session_date) <= contract$analysis_end,
    all(study$sessions$threshold_window_end < study$sessions$session_date),
    all(study$sessions$state_session < study$sessions$session_date),
    max(abs(study$sessions$opening_log_return -
              log(study$sessions$ten_am_price / study$sessions$first_bar_open))) < 1e-12 &&
      max(abs(study$sessions$remainder_log_return -
                log(study$sessions$session_close / study$sessions$ten_am_price))) < 1e-12,
    !anyDuplicated(study$sessions[c("symbol", "session_date")]),
    setequal(unique(study$sessions$era), contract$eras$era)
  ),
  observed = c(
    paste(length(registry$symbol), "symbols"),
    paste("NVDA rows", sum(bars$symbol == contract$excluded_symbol)),
    paste(range(data_health$year), collapse = " to "),
    "Alpaca / SIP / 30Min / all adjusted",
    as.character(max(study$sessions$session_date)),
    paste(range(as.numeric(study$sessions$session_date -
                             study$sessions$threshold_window_end)), collapse = " to "),
    paste(range(as.numeric(study$sessions$session_date -
                             study$sessions$state_session)), collapse = " to "),
    "max absolute difference below 1e-12",
    as.character(sum(duplicated(study$sessions[c("symbol", "session_date")]))),
    paste(unique(study$sessions$era), collapse = ", ")
  ),
  stringsAsFactors = FALSE
)
if (!all(construction_checks$passed)) {
  stop("Opening ATR atlas construction checks failed: ",
       paste(construction_checks$check_id[!construction_checks$passed], collapse = ", "),
       call. = FALSE)
}

registry_lookup <- registry
asset_plot <- merge(registry_lookup, study$asset_summary, by = "symbol", sort = FALSE)
asset_plot <- asset_plot[asset_plot$eligible, , drop = FALSE]
asset_plot <- asset_plot[order(asset_plot$high_minus_low_med_mean), , drop = FALSE]

# 1. Asset-level mechanism breadth.
asset_path <- file.path(visual_dir, "opening_atr_asset_contrasts.png")
grDevices::png(asset_path, width = 2200, height = 1500, res = 180)
graphics::par(mar = c(6.5, 11.5, 7.3, 2.2), family = "sans", bg = "white")
colors <- ifelse(asset_plot$high_minus_low_med_mean < 0, "#14866D", "#B44738")
graphics::barplot(
  100 * asset_plot$high_minus_low_med_mean,
  names.arg = asset_plot$symbol, horiz = TRUE, las = 1,
  col = grDevices::adjustcolor(colors, alpha.f = 0.82), border = NA,
  xlab = "Mean 10:00-close return: HIGH ATR minus LOW/MED ATR (%)",
  main = "Does high prior-day volatility weaken a strong opening across assets?",
  cex.main = 1.38, cex.lab = 1.02, col.main = "#142033", col.lab = "#273548"
)
graphics::abline(v = 0, col = "#344054", lwd = 1.4)
graphics::mtext(
  sprintf("%d/%d eligible assets are negative | asset median %+.3f%%",
          sum(asset_plot$high_minus_low_med_mean < 0), nrow(asset_plot),
          100 * stats::median(asset_plot$high_minus_low_med_mean)),
  side = 3, line = 1.0, cex = 0.90, col = "#5D6878"
)
graphics::mtext(
  "Green supports the mechanism; red contradicts it. Every asset uses its own causal prior-252 opening threshold.",
  side = 1, line = 4.8, cex = 0.78, col = "#667384"
)
grDevices::dev.off()

# 2. Era stability.
era_path <- file.path(visual_dir, "opening_atr_era_stability.png")
era <- study$era_summary
era_matrix <- rbind(
  `LOW / MEDIUM prior ATR` = 100 * era$pooled_low_med_mean_remainder,
  `HIGH prior ATR` = 100 * era$pooled_high_mean_remainder
)
grDevices::png(era_path, width = 2100, height = 1300, res = 180)
graphics::par(mar = c(7.5, 7.2, 7.5, 2.2), family = "sans", bg = "white")
bp <- graphics::barplot(
  era_matrix, beside = TRUE, names.arg = era$era,
  col = c("#3D7EBB", "#B44738"), border = NA,
  ylab = "Pooled mean 10:00-close log return (%)",
  main = "The volatility contrast must persist across eras, not just assets",
  cex.main = 1.42, cex.lab = 1.05, col.main = "#142033", col.lab = "#273548",
  ylim = range(c(0, era_matrix)) + c(-0.12, 0.22) * max(diff(range(c(0, era_matrix))), 0.1)
)
graphics::abline(h = 0, col = "#667384")
graphics::legend("topleft", legend = rownames(era_matrix), fill = c("#3D7EBB", "#B44738"),
                 border = NA, bty = "n", cex = 0.88)
for (i in seq_len(nrow(era))) {
  graphics::text(
    mean(bp[, i]), max(era_matrix[, i]) + 0.08 * max(diff(range(c(0, era_matrix))), 0.1),
    labels = sprintf("asset-median contrast %+.3f%%\n%.0f%% assets negative",
                     100 * era$median_asset_high_minus_low_med[[i]],
                     100 * era$negative_asset_fraction[[i]]),
    cex = 0.78, col = "#344054"
  )
}
graphics::mtext(
  "The 2024-2025 bars are new mechanism evidence from non-NVDA assets; NVDA 2024+ remains unread.",
  side = 1, line = 5.4, cex = 0.80, col = "#667384"
)
grDevices::dev.off()

# 3. Asset response map: continuation under LOW/MED versus HIGH ATR.
scatter_path <- file.path(visual_dir, "opening_atr_asset_response_map.png")
x <- 100 * asset_plot$low_med_mean_remainder
y <- 100 * asset_plot$high_mean_remainder
limit <- max(abs(c(x, y))) * 1.10
grDevices::png(scatter_path, width = 1650, height = 1450, res = 180)
graphics::par(mar = c(7.2, 7.2, 7.0, 2.2), family = "sans", bg = "white")
graphics::plot(
  x, y, pch = ifelse(asset_plot$asset_type == "etf", 17, 16), cex = 1.15,
  col = grDevices::adjustcolor(colors, alpha.f = 0.78),
  xlim = c(-limit, limit), ylim = c(-limit, limit),
  xlab = "Strong-opening mean remainder in LOW/MED ATR (%)",
  ylab = "Strong-opening mean remainder in HIGH ATR (%)",
  main = "Below the diagonal, high volatility weakens the remainder of the day",
  cex.main = 1.35, cex.lab = 1.0, col.main = "#142033", col.lab = "#273548", bty = "n"
)
graphics::abline(h = 0, v = 0, col = "#B9C0C9")
graphics::abline(a = 0, b = 1, lty = 2, col = "#344054")
label_index <- order(abs(asset_plot$high_minus_low_med_mean), decreasing = TRUE)[seq_len(min(10L, nrow(asset_plot)))]
graphics::text(x[label_index], y[label_index], labels = asset_plot$symbol[label_index],
               pos = 3, cex = 0.70, col = "#344054")
graphics::mtext(
  "Dots are stocks; triangles are ETFs. Labels mark the largest absolute state contrasts, not selected winners.",
  side = 1, line = 5.4, cex = 0.78, col = "#667384"
)
grDevices::dev.off()

# 4. Sector summaries provide context without becoming a selection rule.
sector_path <- file.path(visual_dir, "opening_atr_sector_context.png")
sector <- study$sector_summary
sector_colors <- ifelse(sector$median_high_minus_low_med < 0, "#14866D", "#B44738")
grDevices::png(sector_path, width = 2100, height = 1300, res = 180)
graphics::par(mar = c(6.5, 12.5, 7.2, 2.2), family = "sans", bg = "white")
graphics::barplot(
  100 * sector$median_high_minus_low_med,
  names.arg = paste0(sector$sector, " (", sector$assets, ")"),
  horiz = TRUE, las = 1, col = grDevices::adjustcolor(sector_colors, alpha.f = 0.82),
  border = NA, xlab = "Sector median HIGH-minus-LOW/MED response (%)",
  main = "Sector context reveals heterogeneity but does not authorize sector picking",
  cex.main = 1.36, cex.lab = 1.0, col.main = "#142033", col.lab = "#273548"
)
graphics::abline(v = 0, col = "#344054", lwd = 1.3)
graphics::mtext(
  "Each stock sector has two predeclared representatives; broad-market and growth ETFs are separate reference groups.",
  side = 1, line = 4.8, cex = 0.78, col = "#667384"
)
grDevices::dev.off()

# 5. Compact asset-by-era heatmap.
heatmap_path <- file.path(visual_dir, "opening_atr_asset_era_heatmap.png")
asset_era <- merge(registry, study$asset_era_summary, by = "symbol", sort = FALSE)
asset_order <- asset_plot$symbol
mat <- matrix(NA_real_, nrow = length(asset_order), ncol = nrow(contract$eras),
              dimnames = list(asset_order, contract$eras$era))
for (i in seq_len(nrow(asset_era))) {
  if (asset_era$symbol[[i]] %in% rownames(mat) && asset_era$era[[i]] %in% colnames(mat)) {
    mat[asset_era$symbol[[i]], asset_era$era[[i]]] <-
      100 * asset_era$high_minus_low_med_mean[[i]]
  }
}
heat_limit <- max(abs(mat), na.rm = TRUE)
palette <- grDevices::colorRampPalette(c("#14866D", "#F7F8FA", "#B44738"))(201)
grDevices::png(heatmap_path, width = 1500, height = 1800, res = 180)
graphics::par(mar = c(7.8, 9.0, 7.2, 2.2), family = "sans", bg = "white")
graphics::image(
  seq_len(ncol(mat)), seq_len(nrow(mat)), t(mat[nrow(mat):1, , drop = FALSE]),
  col = palette, zlim = c(-heat_limit, heat_limit), axes = FALSE,
  xlab = "Era", ylab = "",
  main = "Asset-level contrasts can change sign across eras",
  cex.main = 1.34, cex.lab = 1.0, col.main = "#142033", col.lab = "#273548"
)
graphics::axis(1, at = seq_len(ncol(mat)), labels = colnames(mat), tick = FALSE)
graphics::axis(2, at = seq_len(nrow(mat)), labels = rev(rownames(mat)), tick = FALSE, las = 1, cex.axis = 0.76)
graphics::box(col = "#CDD3DA")
graphics::mtext(
  "Green = HIGH ATR weaker than LOW/MED; red = HIGH ATR stronger. Blank cells lack five observations in one state.",
  side = 1, line = 5.5, cex = 0.77, col = "#667384"
)
grDevices::dev.off()

run_spec <- data.frame(
  field = c(
    "study_id", "sample_role", "as_of_timestamp", "provider", "feed", "timeframe",
    "adjustment", "source_start", "analysis_start", "analysis_end", "asset_count",
    "symbols", "excluded_symbol", "opening_signal", "atr_state", "response",
    "eras", "costs", "selection", "single_asset_confirmation"
  ),
  value = c(
    contract$study_id, contract$sample_role, contract$as_of_timestamp,
    "Alpaca", "sip", "30Min", "all", as.character(contract$source_start),
    as.character(contract$analysis_start), as.character(contract$analysis_end),
    length(contract$expected_symbols), paste(contract$expected_symbols, collapse = ";"),
    contract$excluded_symbol,
    "first 30-minute log return >= asset-specific prior-252 80th percentile",
    "prior completed session 14-day Wilder ATR% percentile with frozen hysteresis",
    "10:00-to-16:00 log return", paste(contract$eras$era, collapse = ";"),
    "none; mechanism response, not a strategy return", "none; pre-existing registry",
    "NVDA 2024+ remains unread"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(run_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(data_health, file.path(run_dir, "data_health.csv"), row.names = FALSE)
utils::write.csv(construction_checks, file.path(run_dir, "construction_checks.csv"), row.names = FALSE)
utils::write.csv(registry, file.path(run_dir, "atlas_registry.csv"), row.names = FALSE)
utils::write.csv(study$sessions, file.path(run_dir, "session_ledger.csv"), row.names = FALSE)
utils::write.csv(study$asset_summary, file.path(run_dir, "asset_summary.csv"), row.names = FALSE)
utils::write.csv(study$asset_era_summary, file.path(run_dir, "asset_era_summary.csv"), row.names = FALSE)
utils::write.csv(study$era_summary, file.path(run_dir, "era_summary.csv"), row.names = FALSE)
utils::write.csv(study$sector_summary, file.path(run_dir, "sector_summary.csv"), row.names = FALSE)
utils::write.csv(study$pooled_state_summary, file.path(run_dir, "pooled_state_summary.csv"), row.names = FALSE)
utils::write.csv(study$gate$checks, file.path(run_dir, "mechanism_gates.csv"), row.names = FALSE)

report <- c(
  "# Intraday Opening-Tail / Prior-Day ATR Mechanism Atlas",
  "",
  "This atlas asks whether the NVDA clue generalizes: after an unusually strong",
  "first 30 minutes, is the still-tradeable remainder weaker when the prior",
  "completed session was in a HIGH ATR% state? It is a mechanism replication,",
  "not a trading strategy or a sector-selection exercise.",
  "",
  "## Frozen construction",
  "",
  sprintf("- Assets: `%d` pre-existing registry members; NVDA excluded.", length(contract$expected_symbols)),
  sprintf("- Raw coverage: `%s` through `%s`; analyzed outcomes begin `%s`.", contract$source_start, contract$analysis_end, contract$analysis_start),
  "- Opening signal: asset-specific rolling prior-252 80th percentile of 09:30-10:00 log return.",
  "- State: prior completed session's causal 14-day ATR% percentile regime.",
  "- Response: 10:00-to-close log return, without costs.",
  "- NVDA 2024+ intraday outcomes remain unread for the separate one-asset thesis.",
  "",
  "## Readout",
  "",
  sprintf("- Verdict: `%s`", study$gate$verdict),
  sprintf("- Eligible assets: `%d/%d`.", nrow(eligible_assets), nrow(study$asset_summary)),
  sprintf("- Asset-median HIGH-minus-LOW/MED response: `%+.3f%%`.",
          100 * stats::median(eligible_assets$high_minus_low_med_mean)),
  sprintf("- Negative asset fraction: `%.1f%%`.",
          100 * mean(eligible_assets$high_minus_low_med_mean < 0)),
  sprintf("- Pooled LOW/MED strong-opening remainder: `%+.3f%%` (`n=%d`).",
          100 * pooled_low$mean_remainder_log_return, pooled_low$observations),
  sprintf("- Pooled HIGH strong-opening remainder: `%+.3f%%` (`n=%d`).",
          100 * pooled_high$mean_remainder_log_return, pooled_high$observations),
  "",
  "## Era breadth",
  "",
  paste(sprintf(
    "- %s: asset-median contrast `%+.3f%%`; `%.1f%%` of assets negative; pooled HIGH `%+.3f%%`.",
    study$era_summary$era,
    100 * study$era_summary$median_asset_high_minus_low_med,
    100 * study$era_summary$negative_asset_fraction,
    100 * study$era_summary$pooled_high_mean_remainder
  ), collapse = "\n"),
  "",
  "## Interpretation boundary",
  "",
  "A pass says the ATR-dependent response is broad enough to deserve a separate",
  "strategy-design discussion. A stop says the NVDA contrast did not replicate",
  "cleanly. Neither outcome authorizes trading, symbol selection, costs, or",
  "threshold tuning. The sector view is context only.",
  "",
  "## Artifacts",
  "",
  "- `visuals/opening_atr_asset_contrasts.png`",
  "- `visuals/opening_atr_era_stability.png`",
  "- `visuals/opening_atr_asset_response_map.png`",
  "- `visuals/opening_atr_sector_context.png`",
  "- `visuals/opening_atr_asset_era_heatmap.png`",
  "- `asset_summary.csv`",
  "- `asset_era_summary.csv`",
  "- `era_summary.csv`",
  "- `sector_summary.csv`",
  "- `pooled_state_summary.csv`",
  "- `mechanism_gates.csv`"
)
writeLines(report, file.path(run_dir, "report.md"), useBytes = TRUE)

message("Opening ATR mechanism atlas complete")
message("Verdict: ", study$gate$verdict)
message("Eligible assets: ", nrow(eligible_assets), "/", nrow(study$asset_summary))
message("Report: ", file.path(run_dir, "report.md"))
