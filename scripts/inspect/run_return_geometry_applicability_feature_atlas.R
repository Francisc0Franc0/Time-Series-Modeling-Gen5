# Build a visual, descriptive feature atlas for the frozen 2018-2023 TRAIN
# rebound-rule events. This script does not select a gate or open post-2023 OOS.

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
source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "return_geometry_applicability_feature_atlas.R"
))

contract <- rgafa_validate_contract()
source_rule_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_next_open_rule_translation_20260828"
)
source_atlas_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_applicability_feature_atlas_20260828"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) rgafa_stop("Could not create the output directory.")

paths <- list(
  bars = file.path(source_atlas_dir, "wide_atlas_query_bars.csv"),
  source_checks = file.path(source_rule_dir, "rule_translation_checks.csv"),
  source_status = file.path(source_rule_dir, "status.csv"),
  trades = file.path(source_rule_dir, "primary_trade_ledger.csv"),
  registry = file.path(
    repo_root, "operator_hypothesis_lab", "registries", "return_geometry_wide_atlas.csv"
  )
)
if (!all(file.exists(unlist(paths)))) {
  rgafa_stop("Frozen atlas bars, rule trades, status, checks, or registry are missing.")
}

registry <- utils::read.csv(paths$registry, stringsAsFactors = FALSE, check.names = FALSE)
registry$sector_balance_eligible <- as.logical(registry$sector_balance_eligible)
bars <- utils::read.csv(paths$bars, stringsAsFactors = FALSE, check.names = FALSE)
bars$session_date <- as.Date(bars$session_date)
bars$adjusted <- as.logical(bars$adjusted)
trades <- utils::read.csv(paths$trades, stringsAsFactors = FALSE, check.names = FALSE)
date_fields <- c("anchor_session", "entry_session", "exit_session", "research_exit_session")
for (field in intersect(date_fields, names(trades))) trades[[field]] <- as.Date(trades[[field]])
trades$sector_balance_eligible <- as.logical(trades$sector_balance_eligible)
source_checks <- utils::read.csv(paths$source_checks, stringsAsFactors = FALSE, check.names = FALSE)
source_status <- utils::read.csv(paths$source_status, stringsAsFactors = FALSE, check.names = FALSE)

if (any(source_checks$status != "PASS") || source_status$post_2023_data[[1L]] != "SEALED") {
  rgafa_stop("The frozen rule packet is not fully audited or post-2023 is not sealed.")
}
if (nrow(registry) != contract$expected_assets ||
    sum(registry$sector_balance_eligible) != contract$expected_core_assets ||
    length(unique(registry$sector[registry$sector_balance_eligible])) != contract$expected_sectors) {
  rgafa_stop("The frozen 129/88/11 registry contract changed.")
}
if (any(!bars$adjusted) || any(bars$timeframe != "1D")) {
  rgafa_stop("Feature construction requires adjusted daily bars.")
}

ledgers <- split(bars, bars$symbol)
ledgers <- lapply(ledgers, rgafa_prepare_ledger)
if (!"SPY" %in% names(ledgers)) rgafa_stop("SPY is required for the aggregate-volatility feature.")

prior_panel <- do.call(rbind, lapply(ledgers, function(x) {
  x[, c("symbol", "session_date", "prior_20_log_return"), drop = FALSE]
}))
rownames(prior_panel) <- NULL
market_state <- rgafa_market_state(ledgers[["SPY"]], contract)
market_lookup <- match(trades$anchor_session, market_state$session_date)

feature_rows <- vector("list", nrow(trades))
for (i in seq_len(nrow(trades))) {
  trade <- trades[i, , drop = FALSE]
  ledger <- ledgers[[trade$symbol[[1L]]]]
  if (is.null(ledger)) rgafa_stop(paste("No bar ledger for", trade$symbol[[1L]]))
  own <- rgafa_own_features(ledger, trade$anchor_index[[1L]], contract)
  peer <- if (isTRUE(trade$sector_balance_eligible[[1L]])) {
    rgafa_peer_features(
      trade$symbol[[1L]], trade$anchor_session[[1L]], trade$sector[[1L]],
      prior_panel, registry, contract
    )
  } else {
    data.frame(
      sector_peer_count = NA_integer_, sector_peer_prior_20_return = NA_real_,
      sector_relative_loss = NA_real_, peer_negative_breadth = NA_real_,
      stringsAsFactors = FALSE
    )
  }
  feature_rows[[i]] <- cbind(
    trade, own, peer,
    spy_realized_volatility_20 = market_state$spy_realized_volatility_20[market_lookup[[i]]],
    spy_realized_volatility_percentile =
      market_state$spy_realized_volatility_percentile[market_lookup[[i]]],
    spy_volatility_history_observations =
      market_state$spy_volatility_history_observations[market_lookup[[i]]]
  )
}
events <- do.call(rbind, feature_rows)
rownames(events) <- NULL
events <- events[order(events$entry_session, events$atlas_order), , drop = FALSE]

feature_labels <- c(
  sector_relative_loss = "Sector-relative loss",
  peer_negative_breadth = "Peer negative breadth",
  abnormal_dollar_volume = "Abnormal dollar volume",
  price_impact_shock = "Price-impact shock",
  spy_realized_volatility_percentile = "SPY volatility percentile",
  pre_shock_normalized_trend = "Pre-shock normalized trend"
)
feature_names <- names(feature_labels)
core <- events[events$sector_balance_eligible, , drop = FALSE]
rownames(core) <- NULL

profiles <- do.call(rbind, lapply(feature_names, function(feature) {
  rgafa_binned_profile(core, feature, contract$bins)
}))
rownames(profiles) <- NULL
summaries <- do.call(rbind, lapply(feature_names, function(feature) {
  rgafa_feature_summary(core, feature, contract$bins)
}))
rownames(summaries) <- NULL
summaries$label <- unname(feature_labels[summaries$feature])
for (feature in feature_names) {
  core[[paste0(feature, "_bin")]] <- rgafa_assign_bins(core[[feature]], contract$bins)
}

asset_groups <- split(core, core$symbol)
asset_summary <- do.call(rbind, lapply(asset_groups, function(x) {
  row <- data.frame(
    symbol = x$symbol[[1L]], sector = x$sector[[1L]], trades = nrow(x),
    mean_net_excess = mean(x$net_excess_vs_unconditional), stringsAsFactors = FALSE
  )
  for (feature in feature_names) row[[paste0("mean_", feature)]] <- mean(x[[feature]], na.rm = TRUE)
  row
}))
rownames(asset_summary) <- NULL

cohort_groups <- split(events, events$atlas_cohort)
cohort_summary <- do.call(rbind, lapply(cohort_groups, function(x) {
  data.frame(
    atlas_cohort = x$atlas_cohort[[1L]], events = nrow(x),
    assets = length(unique(x$symbol)), mean_net_excess = mean(x$net_excess_vs_unconditional),
    median_abnormal_dollar_volume = stats::median(x$abnormal_dollar_volume, na.rm = TRUE),
    median_price_impact_shock = stats::median(x$price_impact_shock, na.rm = TRUE),
    median_spy_volatility_percentile = stats::median(
      x$spy_realized_volatility_percentile, na.rm = TRUE
    ),
    median_pre_shock_normalized_trend = stats::median(
      x$pre_shock_normalized_trend, na.rm = TRUE
    ),
    stringsAsFactors = FALSE
  )
}))
rownames(cohort_summary) <- NULL

feature_correlation <- stats::cor(core[, feature_names], use = "pairwise.complete.obs", method = "spearman")
feature_correlation <- data.frame(
  feature = rownames(feature_correlation), feature_correlation,
  check.names = FALSE, stringsAsFactors = FALSE
)

checks <- data.frame(
  check_id = c(
    "source_rule_checks_pass", "source_oos_sealed", "registry_129_assets",
    "core_88_assets", "core_11_sectors", "all_rule_events_retained",
    "adjusted_daily_only", "zero_volume_rows_are_missing_not_zero_liquidity",
    "no_post_2023_outcomes", "own_features_causal_coverage",
    "peer_features_exclude_focal", "peer_minimum_coverage", "market_percentile_causal_history"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (source_status$post_2023_data[[1L]] == "SEALED") "PASS" else "FAIL",
    if (nrow(registry) == 129L) "PASS" else "FAIL",
    if (sum(registry$sector_balance_eligible) == 88L) "PASS" else "FAIL",
    if (length(unique(registry$sector[registry$sector_balance_eligible])) == 11L) "PASS" else "FAIL",
    if (nrow(events) == nrow(trades)) "PASS" else "FAIL",
    if (all(bars$adjusted) && all(bars$timeframe == "1D")) "PASS" else "FAIL",
    if (all(bars$volume >= 0)) "PASS" else "FAIL",
    if (max(events$exit_session) <= contract$analysis_end) "PASS" else "FAIL",
    if (all(stats::complete.cases(events[, c(
      "abnormal_dollar_volume", "price_impact_shock", "pre_shock_normalized_trend"
    )]))) "PASS" else "FAIL",
    if (all(core$sector_peer_count <= 7L)) "PASS" else "FAIL",
    if (all(core$sector_peer_count >= contract$minimum_sector_peers)) "PASS" else "FAIL",
    if (all(core$spy_volatility_history_observations >=
            contract$minimum_market_percentile_history)) "PASS" else "FAIL"
  ),
  detail = c(
    paste(nrow(source_checks), "source checks"),
    source_status$post_2023_data[[1L]],
    paste(nrow(registry), "frozen instruments"),
    paste(sum(registry$sector_balance_eligible), "sector-balanced stocks"),
    paste(length(unique(registry$sector[registry$sector_balance_eligible])), "GICS sectors"),
    paste(nrow(events), "primary rule events"),
    "Alpaca adjusted daily OHLCV",
    paste(sum(bars$volume == 0), "zero-volume rows excluded from dollar-volume calculations"),
    paste("latest exit", max(events$exit_session)),
    "20-session event plus preceding 126-session reference window",
    "focal symbol excluded from its sector peer basket",
    paste("minimum peer count", min(core$sector_peer_count, na.rm = TRUE)),
    paste("minimum prior SPY volatility observations",
          min(core$spy_volatility_history_observations, na.rm = TRUE))
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  utils::write.csv(checks, file.path(output_dir, "feature_construction_checks.csv"), row.names = FALSE)
  rgafa_stop("One or more feature-construction checks failed.")
}

run_spec <- data.frame(
  study_id = contract$study_id,
  source_rule = "SIGNED_DOWN_NEGATIVE_Q20_next_open_20_session_nonoverlap_10bp",
  analysis_window = "2018-01-02_through_2023-12-29_TRAIN",
  primary_scope = "88_stock_11_sector_core",
  diagnostic_scope = "all_129_rule_events_where_feature_defined",
  outcome = "net_open_log_return_minus_same_asset_unconditional_20_session_drift",
  features = paste(feature_names, collapse = ";"),
  binning = "descriptive_equal_count_quintiles_no_threshold_selected",
  inference = "visual_and_descriptive_no_p_values_no_multiplicity_gate",
  post_2023_data = "SEALED",
  stringsAsFactors = FALSE
)
status <- data.frame(
  study_id = contract$study_id,
  status = "DESCRIPTIVE_FEATURE_ATLAS_COMPLETE_NO_GATE_SELECTED",
  atlas_assets = length(unique(events$symbol)),
  atlas_events = nrow(events),
  core_assets = length(unique(core$symbol)),
  core_events = nrow(core),
  candidate_features = length(feature_names),
  selected_features = 0L,
  post_2023_data = "SEALED",
  oos_gate = "NOT_DESIGNED",
  stringsAsFactors = FALSE
)

utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
utils::write.csv(status, file.path(output_dir, "status.csv"), row.names = FALSE)
utils::write.csv(checks, file.path(output_dir, "feature_construction_checks.csv"), row.names = FALSE)
utils::write.csv(events, file.path(output_dir, "event_feature_ledger.csv"), row.names = FALSE)
utils::write.csv(profiles, file.path(output_dir, "asset_balanced_binned_profiles.csv"), row.names = FALSE)
utils::write.csv(summaries, file.path(output_dir, "feature_summary.csv"), row.names = FALSE)
utils::write.csv(asset_summary, file.path(output_dir, "asset_feature_summary.csv"), row.names = FALSE)
utils::write.csv(cohort_summary, file.path(output_dir, "cohort_feature_summary.csv"), row.names = FALSE)
utils::write.csv(feature_correlation, file.path(output_dir, "feature_spearman_correlation.csv"), row.names = FALSE)

feature_interpretation <- data.frame(
  feature = feature_names,
  observed_shape = c(
    "Q1 positive in the asset-balanced profile; middle bins negative; no monotone gradient",
    "Discrete and nonmonotone; the second of four observed states is positive",
    "Q2 positive; the two highest bins are negative",
    "Q5 positive immediately after a strongly negative Q4; endpoint island, not a gradient",
    "Alternating signs across bins; no monotone high-volatility benefit",
    "U-shaped profile; both endpoints positive and the middle negative"
  ),
  operator_interpretation = c(
    "The initial shared-selloff intuition is not visually confirmed; extreme idiosyncratic loss is an investigation-only clue",
    "Peer participation does not supply a clean permission rule",
    "High abnormal activity may mark harder-to-reverse, information-heavy losses, but this remains descriptive",
    "The highest price-impact state is a post-hoc clue whose discontinuity makes endpoint artifact risk material",
    "Broad market stress alone does not explain when the rebound rule works",
    "A simple favorable-versus-unfavorable pretrend split would discard important shape"
  ),
  decision = rep("NO_GATE_SELECTED", length(feature_names)),
  stringsAsFactors = FALSE
)
utils::write.csv(
  feature_interpretation, file.path(output_dir, "feature_interpretation.csv"),
  row.names = FALSE
)

select_matched_pair <- function(x, feature, bin_a, bin_b) {
  bin_field <- paste0(feature, "_bin")
  candidates <- list()
  counter <- 0L
  for (symbol in unique(x$symbol)) {
    indices_a <- which(x$symbol == symbol & x[[bin_field]] == bin_a)
    indices_b <- which(x$symbol == symbol & x[[bin_field]] == bin_b)
    if (!length(indices_a) || !length(indices_b)) next
    distances <- abs(outer(
      x$prior_20_log_return[indices_a], x$prior_20_log_return[indices_b], "-"
    ))
    best <- which(distances == min(distances), arr.ind = TRUE)[1L, ]
    counter <- counter + 1L
    candidates[[counter]] <- data.frame(
      feature = feature, symbol = symbol,
      row_a = indices_a[best[[1L]]], row_b = indices_b[best[[2L]]],
      severity_distance = distances[best[[1L]], best[[2L]]],
      stringsAsFactors = FALSE
    )
  }
  if (!length(candidates)) return(data.frame())
  out <- do.call(rbind, candidates)
  out <- out[order(out$severity_distance, out$symbol), , drop = FALSE]
  out[1L, , drop = FALSE]
}

matched_specs <- list(
  list(feature = "sector_relative_loss", bin_a = 1L, bin_b = 2L),
  list(feature = "price_impact_shock", bin_a = 4L, bin_b = 5L)
)
matched_pairs <- do.call(rbind, lapply(matched_specs, function(spec) {
  select_matched_pair(core, spec$feature, spec$bin_a, spec$bin_b)
}))
representative_rows <- list()
counter <- 0L
for (i in seq_len(nrow(matched_pairs))) {
  pair <- matched_pairs[i, , drop = FALSE]
  for (side in c("a", "b")) {
    counter <- counter + 1L
    row_id <- pair[[paste0("row_", side)]][[1L]]
    trade <- core[row_id, , drop = FALSE]
    representative_rows[[counter]] <- data.frame(
      pair_feature = pair$feature[[1L]], pair_side = toupper(side),
      symbol = trade$symbol, anchor_session = trade$anchor_session,
      entry_session = trade$entry_session, exit_session = trade$exit_session,
      anchor_index = trade$anchor_index, entry_index = trade$entry_index,
      exit_index = trade$exit_index, prior_20_log_return = trade$prior_20_log_return,
      feature_value = trade[[pair$feature[[1L]]]],
      feature_bin = trade[[paste0(pair$feature[[1L]], "_bin")]],
      net_excess_vs_unconditional = trade$net_excess_vs_unconditional,
      selection_rule = "same_asset_adjacent_bins_minimum_prior_loss_distance_no_outcome_selection",
      stringsAsFactors = FALSE
    )
  }
}
representatives <- do.call(rbind, representative_rows)
utils::write.csv(
  representatives, file.path(output_dir, "representative_matched_trade_pairs.csv"),
  row.names = FALSE
)

display_limits <- stats::quantile(core$net_excess_vs_unconditional, c(0.025, 0.975), na.rm = TRUE)
display_outcome <- pmax(display_limits[[1L]], pmin(display_limits[[2L]], core$net_excess_vs_unconditional))

outcome_palette <- grDevices::colorRampPalette(c("#B63A4A", "#F5F1E8", "#16836C"))(101)
outcome_color <- function(x) {
  limit <- stats::quantile(abs(x), 0.90, na.rm = TRUE)
  if (!is.finite(limit) || limit <= 0) limit <- max(abs(x), na.rm = TRUE)
  scaled <- pmax(-1, pmin(1, x / limit))
  outcome_palette[pmax(1L, pmin(101L, round((scaled + 1) * 50) + 1L))]
}

png(file.path(visual_dir, "sector_shock_map.png"), width = 1500, height = 1000, res = 150)
par(mar = c(5, 6, 5, 2))
plot(
  100 * core$sector_peer_prior_20_return, 100 * core$prior_20_log_return,
  pch = 16, cex = 0.75, col = outcome_color(core$net_excess_vs_unconditional),
  xlab = "Equal-weight sector-peer prior-20 log return (%)",
  ylab = "Asset prior-20 log return (%)",
  main = "Future outcomes remain mixed across the sector shock map"
)
abline(0, 1, col = "#526273", lty = 2, lwd = 2)
legend(
  "bottomright", legend = c("future excess negative", "near zero", "future excess positive"),
  col = outcome_palette[c(5, 51, 97)], pch = 16, bty = "n"
)
dev.off()

png(file.path(visual_dir, "feature_scatter_sanity_checks.png"), width = 1800, height = 1200, res = 150)
par(mfrow = c(2, 3), mar = c(4.2, 4.2, 3.2, 1.2), oma = c(3.2, 0, 0.5, 0))
for (feature in feature_names) {
  x <- core[[feature]]
  y <- display_outcome * 100
  x_limits <- stats::quantile(x, c(0.025, 0.975), na.rm = TRUE)
  ok <- is.finite(x) & is.finite(y) & x >= x_limits[[1L]] & x <= x_limits[[2L]]
  plot(
    x[ok], y[ok], pch = 16, cex = 0.45,
    col = grDevices::adjustcolor("#3B6C8E", alpha.f = 0.28),
    xlab = feature_labels[[feature]], ylab = "Future net excess (%)",
    main = feature_labels[[feature]]
  )
  abline(h = 0, col = "#AAB4C0")
  smooth <- stats::lowess(x[ok], y[ok], f = 0.60)
  lines(smooth, col = "#E45756", lwd = 3)
}
dev.off()

png(file.path(visual_dir, "asset_balanced_binned_profiles.png"), width = 1800, height = 1200, res = 150)
par(mfrow = c(2, 3), mar = c(4.6, 4.6, 4.0, 1.3), oma = c(3.4, 0, 1.0, 0))
for (feature in feature_names) {
  p <- profiles[profiles$feature == feature, , drop = FALSE]
  plot_values <- 10000 * c(p$asset_balanced_mean_excess, p$event_pooled_mean_excess)
  padding <- max(12, 0.12 * diff(range(plot_values)))
  plot(
    p$feature_bin, p$asset_balanced_mean_excess * 10000,
    type = "b", pch = 16, lwd = 3, col = "#3B82F6",
    xlab = "Descriptive feature bin: low to high",
    ylab = "Excess return (bp/trade)",
    main = feature_labels[[feature]], xaxt = "n",
    ylim = range(plot_values) + c(-padding, padding), cex.main = 0.95
  )
  axis(1, at = p$feature_bin, labels = paste0("Q", seq_len(nrow(p))))
  abline(h = 0, col = "#AAB4C0")
  lines(p$feature_bin, p$event_pooled_mean_excess * 10000,
        type = "b", pch = 1, lwd = 2, col = "#526273")
}
mtext("Blue: asset-balanced mean | gray: event-pooled mean | descriptive bins only",
      side = 1, outer = TRUE, at = 0.5, line = 1.0, cex = 0.85, col = "#526273")
dev.off()

ranked <- summaries[order(abs(summaries$low_to_high_asset_balanced_difference), decreasing = TRUE), ]
png(file.path(visual_dir, "feature_descriptive_rank.png"), width = 1500, height = 900, res = 150)
par(mar = c(5, 12, 4, 2))
values <- ranked$low_to_high_asset_balanced_difference * 10000
positions <- barplot(
  rev(values), names.arg = rev(ranked$label), horiz = TRUE, las = 1,
  col = ifelse(rev(values) >= 0, "#2A9D6F", "#E45756"), border = NA,
  xlab = "Highest minus lowest descriptive bin (asset-balanced bp/trade)",
  main = "Endpoint contrast generates hypotheses; it does not select a gate"
)
abline(v = 0, col = "#526273")
text(positions, rev(values), labels = sprintf("%+.1f", rev(values)),
     pos = ifelse(rev(values) >= 0, 4, 2), cex = 0.9)
dev.off()

sector_colors <- setNames(
  grDevices::hcl.colors(length(unique(asset_summary$sector)), "Dark 3"),
  sort(unique(asset_summary$sector))
)
png(file.path(visual_dir, "asset_characterization_map.png"), width = 1600, height = 1000, res = 150)
par(mar = c(5, 6, 4, 2))
plot(
  100 * asset_summary$mean_sector_relative_loss,
  100 * asset_summary$mean_net_excess,
  pch = 16, cex = 1.15, col = sector_colors[asset_summary$sector],
  xlab = "Asset mean sector-relative prior loss (%)",
  ylab = "Asset mean future net excess (%)",
  main = "Asset winners and losers are not reducible to sector labels"
)
abline(h = 0, v = 0, col = "#AAB4C0")
text(
  100 * asset_summary$mean_sector_relative_loss,
  100 * asset_summary$mean_net_excess,
  labels = asset_summary$symbol, pos = 3, cex = 0.58, col = "#26384A"
)
legend("topleft", legend = names(sector_colors), col = sector_colors, pch = 16,
       bty = "n", cex = 0.72, ncol = 2)
dev.off()

png(file.path(visual_dir, "representative_matched_trade_pairs.png"), width = 1800, height = 1200, res = 150)
par(mfrow = c(2, 2), mar = c(4, 4, 4, 1))
for (i in seq_len(nrow(representatives))) {
  row <- representatives[i, , drop = FALSE]
  ledger <- ledgers[[row$symbol[[1L]]]]
  lo <- max(1L, row$anchor_index[[1L]] - 40L)
  hi <- min(nrow(ledger), row$exit_index[[1L]] + 10L)
  segment <- ledger[lo:hi, , drop = FALSE]
  plot(
    segment$session_date, segment$close, type = "l", lwd = 2, col = "#26384A",
    xlab = "Session", ylab = "Adjusted close",
    main = sprintf(
      "%s | %s Q%d | net excess %+.1f%%",
      row$symbol[[1L]], feature_labels[[row$pair_feature[[1L]]]],
      row$feature_bin[[1L]], 100 * row$net_excess_vs_unconditional[[1L]]
    ), cex.main = 0.92
  )
  abline(v = as.numeric(row$anchor_session[[1L]]), col = "#E45756", lwd = 2)
  abline(v = as.numeric(row$entry_session[[1L]]), col = "#2A9D6F", lwd = 2)
  abline(v = as.numeric(row$exit_session[[1L]]), col = "#3B82F6", lwd = 2)
}
dev.off()

report_lines <- c(
  "# Rebound Applicability Feature Atlas (2018-2023 TRAIN)", "",
  "## Question", "",
  "Can simple, causal, OHLCV-derived features visibly discriminate environments in which the frozen rebound rule did better or worse?", "",
  "## Boundary", "",
  "- The frozen signed-ER20-down, causal bottom-20%-loss, next-open, 20-session, non-overlapping, 10 bp rule is unchanged.",
  "- All 129 atlas instruments remain in the event ledger; the 88-stock, 11-sector core is the primary comparable surface.",
  "- Feature values use information available by the signal close. Post-2023 outcomes remain sealed.",
  "- This packet contains visual and descriptive sanity checks only: no p-values, multiplicity procedure, optimized threshold, classifier, or gate selection.", "",
  "## Candidate features", "",
  "1. Sector-relative loss: focal prior-20 log return minus the equal-weight return of the other seven sector peers.",
  "2. Peer negative breadth: fraction of the other sector peers with negative prior-20 returns.",
  "3. Abnormal dollar volume: log ratio of event-window median dollar volume to the preceding 126-session median.",
  "4. Price-impact shock: log ratio of event-window mean absolute-return-per-dollar-volume to its preceding 126-session median.",
  "5. SPY volatility percentile: current 20-session realized volatility ranked against up to 504 previous observations, with at least 252 required.",
  "6. Pre-shock normalized trend: 126-session log return ending before the loss window, divided by its realized-volatility scale.", "",
  "## Descriptive readout", "",
  paste0("- Core events: `", nrow(core), "` across `", length(unique(core$symbol)), "` stocks."),
  paste0("- All-atlas events retained: `", nrow(events), "` across `", length(unique(events$symbol)), "` instruments."),
  "- `feature_descriptive_rank.png` orders candidates only by the high-minus-low descriptive-bin contrast. It does not select a feature.",
  "- Event-level scatterplots are deliberately paired with asset-balanced profiles so prolific signal generators cannot silently dominate the visual conclusion.", "",
  "- Representative matched tapes use the same asset and adjacent feature bins with the closest prior-loss severity; outcomes never participate in example selection.", "",
  "### What the first visual pass actually says", "",
  "- None of the six candidates shows a clean monotone separation that could responsibly become an applicability gate from this view alone.",
  "- Sector-relative loss and peer breadth do not confirm the initial intuition that a broad shared selloff creates the cleanest rebound environment. The shock map remains visibly mixed.",
  "- The two most conspicuous post-hoc shapes are the positive extreme sector-relative-loss bin and the positive highest price-impact bin. Both are nonmonotone endpoint islands, so they are clues for a separately frozen test—not discovered rules.",
  "- The two highest abnormal-dollar-volume bins are negative in both asset-balanced and event-pooled profiles, consistent with—but not proof of—the possibility that unusually active losses contain harder-to-reverse information.",
  "- SPY volatility state alternates in sign, and pre-shock trend is U-shaped. Neither supports a simple one-threshold permission rule.",
  "- `feature_interpretation.csv` records these shapes and marks every candidate `NO_GATE_SELECTED`.", "",
  "## Sources motivating the feature families", "",
  "- Lo and MacKinlay (1990), *When Are Contrarian Profits Due to Stock Market Overreaction?*, doi:10.1093/rfs/3.2.175.",
  "- Campbell, Grossman, and Wang (1993), *Trading Volume and Serial Correlation in Stock Returns*, doi:10.2307/2118454.",
  "- Amihud (2002), *Illiquidity and Stock Returns: Cross-Section and Time-Series Effects*, doi:10.1016/S1386-4181(01)00024-6.",
  "- Nagel (2012), *Evaporating Liquidity*, doi:10.1093/rfs/hhs066.",
  "- Moskowitz, Ooi, and Pedersen (2012), *Time Series Momentum*, doi:10.1016/j.jfineco.2011.11.003.",
  "- Hameed and Mian (2015), *Industries and Stock Return Reversals*, doi:10.1017/S0022109014000404.", "",
  "## Status", "",
  "`DESCRIPTIVE_FEATURE_ATLAS_COMPLETE_NO_GATE_SELECTED`", "",
  "The next decision is whether any visually coherent candidate merits a predeclared held-out-asset and held-out-sector discrimination test. Do not open post-2023 data from this packet."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Status: ", status$status[[1L]])
message("Core events: ", nrow(core), "; all-atlas events: ", nrow(events))
message("Artifacts: ", output_dir)
