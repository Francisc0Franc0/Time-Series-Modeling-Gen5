# Decompose the transported signed-down loss-rebound pattern into common-sample,
# non-overlapping future blocks. This is a descriptive timing falsification,
# not a temporal confirmation, parameter search, portfolio replay, or PnL test.

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
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_direction.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_reg_01_1_atr_percent.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "own_asset_return_geometry_atlas.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "return_geometry_wide_atlas.R"))
source(file.path(
  repo_root, "operator_hypothesis_lab", "R",
  "return_geometry_incremental_forward_decomposition.R"
))

contract <- rgifd_contract()
blocks <- rgifd_validate_blocks(contract = contract)
source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_incremental_forward_decomposition_20260827"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) rgifd_stop("Could not create the output directory.")

paths <- list(
  bars = file.path(source_dir, "wide_atlas_query_bars.csv"),
  source_cells = file.path(source_dir, "asset_prior_sign_cells.csv"),
  coverage = file.path(source_dir, "coverage_ledger.csv"),
  source_checks = file.path(source_dir, "wide_atlas_checks.csv"),
  registry = file.path(
    repo_root, "operator_hypothesis_lab", "registries", "return_geometry_wide_atlas.csv"
  )
)
if (!all(file.exists(unlist(paths)))) {
  rgifd_stop("The frozen wide-atlas bars, cells, coverage, checks, or registry are unavailable.")
}

wide_contract <- rgwa_contract()
registry <- rgwa_validate_registry(utils::read.csv(
  paths$registry, stringsAsFactors = FALSE, check.names = FALSE
), wide_contract)
bars <- utils::read.csv(paths$bars, stringsAsFactors = FALSE, check.names = FALSE)
bars$session_date <- as.Date(bars$session_date)
bars$adjusted <- as.logical(bars$adjusted)
coverage <- utils::read.csv(paths$coverage, stringsAsFactors = FALSE, check.names = FALSE)
coverage$full_frozen_history <- as.logical(coverage$full_frozen_history)
source_checks <- utils::read.csv(paths$source_checks, stringsAsFactors = FALSE, check.names = FALSE)
source_cells <- utils::read.csv(paths$source_cells, stringsAsFactors = FALSE, check.names = FALSE)

if (any(source_checks$status != "PASS")) {
  rgifd_stop("The source wide-atlas packet does not have a complete PASS audit.")
}
core_coverage <- coverage[coverage$atlas_cohort == "GICS_CORE", , drop = FALSE]
if (nrow(core_coverage) != contract$expected_core_assets || !all(core_coverage$full_frozen_history)) {
  rgifd_stop("The equal-sector core is not fully covered in the frozen source packet.")
}

asset_rows <- vector("list", nrow(registry))
parity_rows <- list()
parity_index <- 0L
identity_errors <- numeric(nrow(registry))
primary_state_prior_negative <- logical(nrow(registry))
common_anchor_equal <- logical(nrow(registry))
ledgers <- vector("list", nrow(registry))
names(ledgers) <- registry$symbol
shared_parity_ends <- c(5L, 10L, 20L, 40L, 100L)

for (i in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[i]]
  message(sprintf("[%03d/%03d] %s", i, nrow(registry), symbol))
  ledger <- rgwa_build_ledger(bars, symbol, wide_contract)
  ledgers[[symbol]] <- ledger
  surface <- rgifd_construct_surface(ledger, contract, blocks)
  asset_rows[[i]] <- rgifd_measure_asset(surface, contract, blocks)

  common_anchor_equal[[i]] <- length(unique(table(surface$block_id))) == 1L
  primary_rows <- !is.na(surface$signed_er20_state) &
    surface$signed_er20_state == contract$state
  primary_state_prior_negative[[i]] <- all(
    surface$prior_cumulative_log_return[primary_rows] < 0
  )
  incremental_sum <- stats::aggregate(
    forward_incremental_log_return ~ anchor_session,
    data = surface, FUN = sum
  )
  cumulative_100 <- surface[
    surface$block_id == "B61_100",
    c("anchor_session", "forward_cumulative_log_return"), drop = FALSE
  ]
  identity <- merge(incremental_sum, cumulative_100, by = "anchor_session", sort = FALSE)
  identity_errors[[i]] <- max(abs(
    identity$forward_incremental_log_return - identity$forward_cumulative_log_return
  ))

  for (forward_sessions in shared_parity_ends) {
    variable_surface <- oarga_construct_surface(
      ledger, contract$prior_sessions, forward_sessions, wide_contract
    )
    described <- oarga_describe_sign(
      variable_surface, contract$state, contract$state_column,
      contract$minimum_observations
    )
    source_row <- source_cells[
      source_cells$symbol == symbol & source_cells$condition == "SIGNED_ER20" &
        source_cells$state == contract$state &
        source_cells$prior_sessions == contract$prior_sessions &
        source_cells$forward_sessions == forward_sessions,
      , drop = FALSE
    ]
    parity_index <- parity_index + 1L
    parity_rows[[parity_index]] <- data.frame(
      symbol = symbol,
      forward_sessions = forward_sessions,
      recomputed_negative_pearson = described$negative_pearson_correlation,
      source_negative_pearson = if (nrow(source_row) == 1L) {
        source_row$negative_pearson_correlation[[1L]]
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
}

asset_metrics <- do.call(rbind, asset_rows)
rownames(asset_metrics) <- NULL
asset_metrics <- merge(
  asset_metrics, registry,
  by = "symbol", all.x = TRUE, sort = FALSE
)
asset_metrics <- asset_metrics[order(asset_metrics$atlas_order, asset_metrics$block_order), , drop = FALSE]

parity <- do.call(rbind, parity_rows)
parity$absolute_difference <- abs(
  parity$recomputed_negative_pearson - parity$source_negative_pearson
)
parity_max <- max(parity$absolute_difference, na.rm = TRUE)

group_fields <- c(
  "block_order", "block_id", "block_label", "block_start", "block_end", "block_sessions"
)
core_metrics <- asset_metrics[asset_metrics$sector_balance_eligible, , drop = FALSE]
sector_summary <- rgifd_summarize_metrics(
  core_metrics, c("sector", group_fields)
)
equal_sector <- rgifd_summarize_metrics(sector_summary, group_fields)
cohort_summary <- rgifd_summarize_metrics(
  asset_metrics, c("atlas_cohort", group_fields)
)
equal_asset <- rgifd_summarize_metrics(asset_metrics, group_fields)

equal_sector$negative_incremental_sectors <- vapply(
  equal_sector$block_id,
  function(block_id) sum(
    is.finite(sector_summary$primary_incremental_pearson[sector_summary$block_id == block_id]) &
      sector_summary$primary_incremental_pearson[sector_summary$block_id == block_id] < 0
  ),
  integer(1L)
)
equal_sector$positive_excess_sectors <- vapply(
  equal_sector$block_id,
  function(block_id) sum(
    is.finite(sector_summary$incremental_excess_mean_per_session[sector_summary$block_id == block_id]) &
      sector_summary$incremental_excess_mean_per_session[sector_summary$block_id == block_id] > 0
  ),
  integer(1L)
)
equal_sector$negative_incremental_sector_fraction <-
  equal_sector$negative_incremental_sectors / contract$expected_sectors
equal_sector$positive_excess_sector_fraction <-
  equal_sector$positive_excess_sectors / contract$expected_sectors

duration <- rgifd_classify_duration(equal_sector, sector_summary, contract)
late_block_readout <- duration$late

checks <- data.frame(
  check_id = c(
    "source_packet_pass", "registry_exact", "core_full_history",
    "block_registry_exact", "asset_block_rows_exact", "common_anchor_sample",
    "incremental_identity", "signed_down_prior_negative", "shared_cell_parity",
    "no_post_2023_outcomes", "adjusted_daily_only", "post_2023_sealed"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (nrow(registry) == contract$expected_assets) "PASS" else "FAIL",
    if (nrow(core_coverage) == contract$expected_core_assets && all(core_coverage$full_frozen_history)) "PASS" else "FAIL",
    if (identical(blocks, rgifd_block_registry())) "PASS" else "FAIL",
    if (nrow(asset_metrics) == contract$expected_assets * nrow(blocks)) "PASS" else "FAIL",
    if (all(common_anchor_equal)) "PASS" else "FAIL",
    if (max(identity_errors) < 1e-12) "PASS" else "FAIL",
    if (all(primary_state_prior_negative)) "PASS" else "FAIL",
    if (is.finite(parity_max) && parity_max < 1e-12) "PASS" else "FAIL",
    if (max(bars$session_date) <= contract$analysis_end) "PASS" else "FAIL",
    if (all(bars$adjusted) && all(bars$timeframe == "1D")) "PASS" else "FAIL",
    "PASS"
  ),
  detail = c(
    paste(nrow(source_checks), "source checks"),
    paste(nrow(registry), "frozen assets"),
    paste(nrow(core_coverage), "full-history core assets"),
    paste(blocks$block_label, collapse = ","),
    paste(nrow(asset_metrics), "asset-block rows"),
    "every asset uses one common anchor set across all six blocks",
    format(max(identity_errors), scientific = TRUE),
    "signed ER20 DOWN anchors imply a negative 20-session prior return",
    format(parity_max, scientific = TRUE),
    as.character(max(bars$session_date)),
    "Alpaca adjusted 1D bars",
    "no post-2023 file or outcome queried"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  utils::write.csv(checks, file.path(output_dir, "decomposition_checks.csv"), row.names = FALSE)
  rgifd_stop("One or more decomposition checks failed.")
}

utils::write.csv(blocks, file.path(output_dir, "block_registry.csv"), row.names = FALSE)
utils::write.csv(asset_metrics, file.path(output_dir, "asset_block_metrics.csv"), row.names = FALSE, na = "")
utils::write.csv(sector_summary, file.path(output_dir, "core_sector_block_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(equal_sector, file.path(output_dir, "equal_sector_block_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(cohort_summary, file.path(output_dir, "cohort_block_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(equal_asset, file.path(output_dir, "equal_asset_block_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(parity, file.path(output_dir, "shared_cell_parity.csv"), row.names = FALSE, na = "")
utils::write.csv(late_block_readout, file.path(output_dir, "late_block_readout.csv"), row.names = FALSE, na = "")
utils::write.csv(checks, file.path(output_dir, "decomposition_checks.csv"), row.names = FALSE)

run_spec <- data.frame(
  field = c(
    "study_id", "source_packet", "provider", "bar_contract", "analysis_window",
    "prior_anchor", "primary_filter", "primary_branch", "forward_blocks",
    "common_sample_rule", "primary_universe", "secondary_universe",
    "primary_outcomes", "actionability_descriptor", "context_comparator",
    "late_support_rule", "inference", "post_2023_data", "trading_calculation"
  ),
  value = c(
    contract$study_id,
    "return_geometry_wide_atlas_full_vocabulary_20260827",
    "Alpaca SIP", "adjusted daily OHLCV",
    paste(contract$analysis_start, contract$analysis_end, sep = " to "),
    "20-session cumulative log return",
    "signed ER20 DOWN_TREND at the anchor",
    "negative prior return",
    paste(blocks$block_label, collapse = ","),
    "all observations must have the complete following 100 sessions",
    "88-stock full-history GICS core; median within sector then median across 11 sectors",
    "all 129 assets retained by cohort and asset",
    "incremental/cumulative Pearson, Spearman, and OLS slope",
    "conditional minus same-asset unconditional mean log return; total and per session",
    "unfiltered negative-prior branch",
    "late block supportive when median r < 0, at least 7/11 sector medians < 0, and drift-adjusted return/session > 0; duration survives at 2/3 late blocks",
    "none; descriptive timing falsification",
    "sealed", "none"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

colors <- list(
  coral = "#E45756", blue = "#3D8DFF", green = "#2A9D6F",
  purple = "#7C3AED", amber = "#F59E0B", ink = "#243247",
  muted = "#667384", rule = "#CBD5E1", cream = "#F7F3E8"
)
block_axis <- seq_len(nrow(blocks))
plot_limits <- range(c(
  equal_sector$primary_incremental_pearson,
  equal_sector$primary_cumulative_pearson,
  equal_sector$unfiltered_loss_incremental_pearson,
  0
), finite = TRUE)
plot_limits <- plot_limits + c(-0.04, 0.04)
grDevices::png(
  file.path(visual_dir, "cumulative_vs_incremental_correlation.png"),
  width = 1800, height = 1050, res = 170
)
graphics::par(mar = c(6, 6, 4, 2))
graphics::plot(
  block_axis, equal_sector$primary_incremental_pearson,
  type = "o", pch = 16, lwd = 4, col = colors$coral,
  ylim = plot_limits, xaxt = "n", xlab = "Non-overlapping following block",
  ylab = "Equal-sector median Pearson r",
  main = "Signed-down loss response: cumulative persistence versus incremental timing"
)
graphics::axis(1, at = block_axis, labels = blocks$block_label)
graphics::abline(h = 0, col = colors$rule, lwd = 2)
graphics::lines(
  block_axis, equal_sector$primary_cumulative_pearson,
  type = "o", pch = 15, lwd = 4, col = colors$blue
)
graphics::lines(
  block_axis, equal_sector$unfiltered_loss_incremental_pearson,
  type = "o", pch = 1, lwd = 2, lty = 2, col = colors$muted
)
graphics::legend(
  "bottomright",
  legend = c("Signed-down incremental", "Signed-down cumulative", "Unfiltered-loss incremental"),
  col = c(colors$coral, colors$blue, colors$muted),
  lwd = c(4, 4, 2), pch = c(16, 15, 1), lty = c(1, 1, 2), bty = "n"
)
grDevices::dev.off()

sector_levels <- sort(unique(sector_summary$sector))
sector_matrix <- matrix(
  NA_real_, nrow = length(sector_levels), ncol = nrow(blocks),
  dimnames = list(sector_levels, blocks$block_label)
)
for (i in seq_len(nrow(sector_summary))) {
  sector_matrix[
    sector_summary$sector[[i]], sector_summary$block_label[[i]]
  ] <- sector_summary$primary_incremental_pearson[[i]]
}
heat_limit <- max(abs(sector_matrix), na.rm = TRUE)
heat_limit <- max(0.10, heat_limit)
heat_palette <- grDevices::colorRampPalette(c("#8B1E3F", colors$cream, "#0E7490"))(201)
grDevices::png(
  file.path(visual_dir, "incremental_sector_heatmap.png"),
  width = 1800, height = 1200, res = 170
)
graphics::par(mar = c(6, 15, 4, 2))
graphics::image(
  seq_len(nrow(blocks)), seq_along(sector_levels), t(sector_matrix),
  col = heat_palette, zlim = c(-heat_limit, heat_limit), axes = FALSE,
  xlab = "Non-overlapping following block", ylab = "",
  main = "Where the signed-down loss response arrives by sector"
)
graphics::axis(1, at = seq_len(nrow(blocks)), labels = blocks$block_label)
graphics::axis(2, at = seq_along(sector_levels), labels = sector_levels, las = 1)
for (r in seq_along(sector_levels)) for (c in seq_len(nrow(blocks))) {
  value <- sector_matrix[r, c]
  if (is.finite(value)) graphics::text(c, r, sprintf("%+.2f", value), cex = 0.72)
}
grDevices::dev.off()

core_metrics$block_label_factor <- factor(
  core_metrics$block_label, levels = blocks$block_label
)
grDevices::png(
  file.path(visual_dir, "incremental_asset_distribution.png"),
  width = 1800, height = 1050, res = 170
)
graphics::par(mar = c(6, 6, 4, 2))
graphics::boxplot(
  primary_incremental_pearson ~ block_label_factor,
  data = core_metrics, col = "#EDF5FF", border = colors$blue,
  outline = FALSE, xlab = "Non-overlapping following block",
  ylab = "Per-asset Pearson r",
  main = "The 88-stock core reveals whether late-block support is broad"
)
graphics::abline(h = 0, col = colors$rule, lwd = 2)
set.seed(20260827)
graphics::stripchart(
  primary_incremental_pearson ~ block_label_factor,
  data = core_metrics, vertical = TRUE, method = "jitter", add = TRUE,
  pch = 16, cex = 0.52, col = grDevices::adjustcolor(colors$ink, alpha.f = 0.42)
)
grDevices::dev.off()

excess_bp <- 10000 * equal_sector$incremental_excess_mean_per_session
bar_colors <- ifelse(excess_bp >= 0, colors$green, colors$coral)
excess_limits <- c(min(excess_bp) - 1.4, max(excess_bp) + 1.8)
grDevices::png(
  file.path(visual_dir, "incremental_excess_bp_per_session.png"),
  width = 1800, height = 1050, res = 170
)
graphics::par(mar = c(6, 6, 4, 2))
bar_positions <- graphics::barplot(
  excess_bp, names.arg = blocks$block_label, col = bar_colors, border = NA,
  ylim = excess_limits,
  xlab = "Non-overlapping following block",
  ylab = "Conditional excess log return (bp per session)",
  main = "Does the signed-down state add return beyond unconditional drift?"
)
graphics::abline(h = 0, col = colors$ink, lwd = 1.5)
graphics::text(
  bar_positions, excess_bp,
  labels = sprintf("%+.2f\n%d/11 sectors", excess_bp, equal_sector$positive_excess_sectors),
  pos = ifelse(excess_bp >= 0, 3, 1), offset = 0.45,
  cex = 0.82, col = colors$ink, xpd = NA
)
grDevices::dev.off()

status <- data.frame(
  study_id = contract$study_id,
  status = duration$status,
  supportive_late_blocks = duration$supportive_late_blocks,
  total_late_blocks = length(contract$late_block_ids),
  post_2023_data = "SEALED",
  temporal_confirmation = "NOT_OPENED",
  trading_calculation = "NOT_RUN",
  stringsAsFactors = FALSE
)
utils::write.csv(status, file.path(output_dir, "status.csv"), row.names = FALSE)

format_block_line <- function(row) {
  sprintf(
    "- **%s:** incremental r `%+.3f`; cumulative r `%+.3f`; `%d/11` sector medians negative; drift-adjusted incremental return `%+.2f bp/session`; `%d/11` sector excess medians positive.",
    row$block_label, row$primary_incremental_pearson,
    row$primary_cumulative_pearson, row$negative_incremental_sectors,
    10000 * row$incremental_excess_mean_per_session,
    row$positive_excess_sectors
  )
}
report <- c(
  "# Incremental Forward-Return Decomposition (2018-2023)", "",
  "## Question", "",
  "Does the transported signed-ER20 down-state loss-rebound relationship reflect an early rebound embedded in every longer cumulative target, or does new conditional return continue to arrive in later non-overlapping blocks?", "",
  "## Frozen microscope", "",
  "- Frozen 129-instrument atlas; the full-history 88-stock, 11-sector core is the primary equal-sector surface.",
  "- Exactly 20 prior sessions, a negative prior log return, and signed ER20 `DOWN_TREND` at the anchor.",
  "- Non-overlapping future blocks: `1-5`, `6-10`, `11-20`, `21-40`, `41-60`, and `61-100`.",
  "- Every block uses the same anchors with a complete 100-session future path.",
  "- Primary timing outcomes are incremental correlation and slope. Conditional mean return above same-asset unconditional drift is a secondary actionability descriptor.",
  "- The unfiltered negative-prior branch is the only context comparator. No other filters, prior horizons, inference, PnL, or post-2023 outcomes are opened.", "",
  "## Equal-sector timing readout", "",
  unlist(lapply(seq_len(nrow(equal_sector)), function(i) format_block_line(equal_sector[i, , drop = FALSE]))), "",
  "## Frozen descriptive duration rule", "",
  "A late block is supportive only when its equal-sector median incremental correlation is negative, at least 7/11 sector medians are negative, and its equal-sector drift-adjusted return per session is positive. Two of the three late blocks are required to retain descriptive duration support.", "",
  sprintf("- Supportive late blocks: `%d/3`.", duration$supportive_late_blocks),
  sprintf("- Status: `%s`.", duration$status), "",
  "## Interpretation boundary", "",
  "- Incremental blocks locate when the relationship appears; cumulative targets cannot do that because they inherit every earlier return.",
  "- Positive drift-adjusted return is descriptive, not an executable edge. Overlapping anchors, event definition, costs, path risk, temporal transport, and opportunity cost remain unresolved.",
  "- The classification is a frozen directional morphology rule, not inferential evidence or a promotion to trading authority.", "",
  "## Artifacts", "",
  "- `asset_block_metrics.csv`: per-asset incremental/cumulative timing and drift descriptors.",
  "- `core_sector_block_summary.csv` and `equal_sector_block_summary.csv`: primary breadth surface.",
  "- `cohort_block_summary.csv`: attention, ETF, and non-equity context.",
  "- `decomposition_checks.csv` and `shared_cell_parity.csv`: construction audit.",
  "- `visuals/`: timing curve, sector heatmap, asset distribution, and excess-return chart.", "",
  "## STOP / next gate", "",
  "Stop at the descriptive timing result. Do not infer a holding period, select another filter or horizon, or query post-2023 outcomes. The next gate depends on whether late incremental duration retained support."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

message(sprintf("STATUS: %s", duration$status))
message(sprintf("Supportive late blocks: %d/3", duration$supportive_late_blocks))
message(sprintf("Artifacts: %s", output_dir))
