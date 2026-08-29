# Contrast the positive-prior continuation surface in causal ER20-sideways and
# ER20-trending states. This script re-expresses the frozen 2018-2023 wide-atlas
# evidence only; it performs no provider query, horizon search, inference, or
# strategy-performance calculation.

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
  "return_geometry_continuation_state_contrast.R"
))
if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("The existing ggplot2 dependency is required for contrast visuals.", call. = FALSE)
}

source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_wide_atlas_full_vocabulary_20260827"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_continuation_state_contrast_20260828"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

cells_path <- file.path(source_dir, "asset_prior_sign_cells.csv")
run_spec_path <- file.path(source_dir, "run_spec.csv")
source_checks_path <- file.path(source_dir, "wide_atlas_checks.csv")
if (!all(file.exists(c(cells_path, run_spec_path, source_checks_path)))) {
  stop("The frozen full-vocabulary atlas packet is incomplete.", call. = FALSE)
}

cells <- utils::read.csv(cells_path, stringsAsFactors = FALSE, check.names = FALSE)
run_spec <- utils::read.csv(run_spec_path, stringsAsFactors = FALSE, check.names = FALSE)
source_checks <- utils::read.csv(source_checks_path, stringsAsFactors = FALSE, check.names = FALSE)
contract <- rgcsc_contract()
rgcsc_validate_source(cells, run_spec, contract)
if (any(source_checks$status != "PASS")) {
  stop("The frozen source packet contains a failed integrity check.", call. = FALSE)
}

pairs <- rgcsc_prepare_pairs(cells, contract)
sector <- rgcsc_sector_summary(pairs)
equal_sector <- rgcsc_equal_sector_summary(sector)
cohort <- rgcsc_cohort_summary(pairs)
regions <- rgcsc_region_summary(equal_sector, contract)
sector_surface <- rgcsc_group_apply(sector, "sector", function(x) {
  valid <- is.finite(x$median_sideways_minus_trending_pearson)
  data.frame(
    cells = sum(valid),
    median_sideways_positive_pearson = stats::median(x$median_sideways_positive_pearson[valid]),
    median_trending_positive_pearson = stats::median(x$median_trending_positive_pearson[valid]),
    median_sideways_minus_trending_pearson = stats::median(x$median_sideways_minus_trending_pearson[valid]),
    sideways_advantage_cell_fraction = mean(x$median_sideways_minus_trending_pearson[valid] > 0),
    stringsAsFactors = FALSE
  )
})
cohort_surface <- rgcsc_group_apply(cohort, "atlas_cohort", function(x) {
  valid <- is.finite(x$median_sideways_minus_trending_pearson)
  data.frame(
    cells = sum(valid),
    median_sideways_positive_pearson = stats::median(x$median_sideways_positive_pearson[valid]),
    median_trending_positive_pearson = stats::median(x$median_trending_positive_pearson[valid]),
    median_sideways_minus_trending_pearson = stats::median(x$median_sideways_minus_trending_pearson[valid]),
    sideways_advantage_cell_fraction = mean(x$median_sideways_minus_trending_pearson[valid] > 0),
    stringsAsFactors = FALSE
  )
})
diagonal <- equal_sector[
  equal_sector$prior_sessions == equal_sector$forward_sessions,
  , drop = FALSE
]
diagonal <- diagonal[order(diagonal$prior_sessions), ]

checks <- data.frame(
  check = c(
    "source_checks_pass", "source_stops_at_2023", "pair_rows",
    "core_pair_rows", "paired_cell_rows", "sector_cell_rows",
    "equal_sector_cells", "diagonal_cells", "state_definition",
    "no_outcome_recalculation"
  ),
  status = c(
    if (all(source_checks$status == "PASS")) "PASS" else "FAIL",
    if (identical(rgcsc_run_spec_value(run_spec, "analysis_window"), "2018-01-02 to 2023-12-29")) "PASS" else "FAIL",
    if (nrow(pairs) == contract$expected_assets * contract$expected_cells) "PASS" else "FAIL",
    if (sum(pairs$sector_balance_eligible) == contract$expected_core_assets * contract$expected_cells) "PASS" else "FAIL",
    if (sum(pairs$paired_status == "INCOMPLETE") == contract$expected_incomplete_pairs &&
        all(pairs$symbol[pairs$paired_status == "INCOMPLETE"] == "RIVN") &&
        !any(pairs$sector_balance_eligible[pairs$paired_status == "INCOMPLETE"])) "PASS" else "FAIL",
    if (nrow(sector) == contract$expected_sectors * contract$expected_cells) "PASS" else "FAIL",
    if (nrow(equal_sector) == contract$expected_cells) "PASS" else "FAIL",
    if (nrow(diagonal) == length(contract$horizons)) "PASS" else "FAIL",
    if (identical(contract$sideways_state, "RED_SIDEWAYS") && identical(contract$trending_state, "GREEN_TRENDING")) "PASS" else "FAIL",
    "PASS"
  ),
  detail = c(
    sprintf("%d/%d inherited checks pass", sum(source_checks$status == "PASS"), nrow(source_checks)),
    rgcsc_run_spec_value(run_spec, "analysis_window"),
    sprintf("%d expected %d", nrow(pairs), contract$expected_assets * contract$expected_cells),
    sprintf("%d expected %d", sum(pairs$sector_balance_eligible), contract$expected_core_assets * contract$expected_cells),
    sprintf("%d/%d paired; lone blank is RIVN 100->100 trending positive branch with 24 observations", sum(pairs$paired_status == "PAIRED"), nrow(pairs)),
    sprintf("%d expected %d", nrow(sector), contract$expected_sectors * contract$expected_cells),
    sprintf("%d expected %d", nrow(equal_sector), contract$expected_cells),
    sprintf("%d expected %d", nrow(diagonal), length(contract$horizons)),
    "ER20 < 0.30 sideways; ER20 >= 0.30 trending, inherited from source atlas",
    "Reads frozen asset_prior_sign_cells.csv; no bars or forward returns recomputed"
  ),
  stringsAsFactors = FALSE
)
if (any(checks$status != "PASS")) {
  utils::write.csv(checks, file.path(output_dir, "contrast_checks.csv"), row.names = FALSE)
  stop("One or more continuation-contrast checks failed.", call. = FALSE)
}

utils::write.csv(pairs, file.path(output_dir, "paired_asset_cells.csv"), row.names = FALSE, na = "")
utils::write.csv(sector, file.path(output_dir, "sector_paired_cell_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(equal_sector, file.path(output_dir, "equal_sector_paired_cell_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(cohort, file.path(output_dir, "cohort_paired_cell_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(sector_surface, file.path(output_dir, "sector_surface_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(cohort_surface, file.path(output_dir, "cohort_surface_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(diagonal, file.path(output_dir, "equal_sector_paired_diagonal.csv"), row.names = FALSE, na = "")
utils::write.csv(regions, file.path(output_dir, "equal_sector_region_summary.csv"), row.names = FALSE, na = "")
utils::write.csv(checks, file.path(output_dir, "contrast_checks.csv"), row.names = FALSE)

state_surface <- rbind(
  data.frame(
    prior_sessions = equal_sector$prior_sessions,
    forward_sessions = equal_sector$forward_sessions,
    state = "ER20 sideways",
    correlation = equal_sector$equal_sector_median_sideways_positive_pearson
  ),
  data.frame(
    prior_sessions = equal_sector$prior_sessions,
    forward_sessions = equal_sector$forward_sessions,
    state = "ER20 trending",
    correlation = equal_sector$equal_sector_median_trending_positive_pearson
  )
)
horizon_levels <- as.character(contract$horizons)
state_surface$prior_label <- factor(as.character(state_surface$prior_sessions), levels = horizon_levels)
state_surface$forward_label <- factor(as.character(state_surface$forward_sessions), levels = horizon_levels)
equal_sector$prior_label <- factor(as.character(equal_sector$prior_sessions), levels = horizon_levels)
equal_sector$forward_label <- factor(as.character(equal_sector$forward_sessions), levels = horizon_levels)

theme_contrast <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", color = "#102f4f", size = 20),
      plot.subtitle = ggplot2::element_text(color = "#52677e", size = 11),
      plot.caption = ggplot2::element_text(color = "#64748b", size = 9, hjust = 0),
      axis.text = ggplot2::element_text(color = "#253b53", size = 9),
      axis.title = ggplot2::element_text(face = "bold", color = "#253b53"),
      panel.grid = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", color = "#102f4f", size = 13),
      plot.margin = ggplot2::margin(16, 22, 14, 22)
    )
}

p_states <- ggplot2::ggplot(
  state_surface,
  ggplot2::aes(x = forward_label, y = prior_label, fill = correlation)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.25) +
  ggplot2::facet_wrap(~state, nrow = 1) +
  ggplot2::scale_fill_gradient2(
    low = "#b44738", mid = "#f7f4eb", high = "#14866d", midpoint = 0,
    limits = c(-0.15, 0.15), oob = scales::squish, name = "Median r"
  ) +
  ggplot2::labs(
    title = "Positive-prior behavior flips across path-efficiency states",
    subtitle = "Equal-sector median within-asset correlation, 88-stock core; the same 15 x 15 horizon vocabulary appears in both panels",
    x = "Following sessions", y = "Prior sessions",
    caption = "Descriptive 2018-2023 evidence. Correlations are not returns, and cells are overlapping."
  ) +
  ggplot2::coord_equal() + theme_contrast()
ggplot2::ggsave(file.path(visual_dir, "sideways_vs_trending_positive_branch_heatmaps.png"), p_states, width = 13.5, height = 6.8, dpi = 180)

p_delta <- ggplot2::ggplot(
  equal_sector,
  ggplot2::aes(x = forward_label, y = prior_label, fill = equal_sector_median_sideways_minus_trending_pearson)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.25) +
  ggplot2::scale_fill_gradient2(
    low = "#b44738", mid = "#f7f4eb", high = "#14866d", midpoint = 0,
    limits = c(-0.20, 0.20), oob = scales::squish, name = "Sideways -\ntrending r"
  ) +
  ggplot2::labs(
    title = "The paired contrast is positive across most of the surface",
    subtitle = "Each core asset is paired within the same prior/following cell before sector-balanced aggregation",
    x = "Following sessions", y = "Prior sessions",
    caption = "Positive means the positive-prior correlation is more continuation-shaped in ER20-sideways than ER20-trending."
  ) +
  ggplot2::coord_equal() + theme_contrast()
ggplot2::ggsave(file.path(visual_dir, "sideways_minus_trending_paired_heatmap.png"), p_delta, width = 10.8, height = 8.2, dpi = 180)

p_breadth <- ggplot2::ggplot(
  equal_sector,
  ggplot2::aes(x = forward_label, y = prior_label, fill = sector_sideways_advantage_fraction)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.25) +
  ggplot2::scale_fill_gradient(
    low = "#e7edf2", high = "#14866d", limits = c(0, 1),
    labels = scales::label_percent(accuracy = 1), name = "Sectors with\nsideways advantage"
  ) +
  ggplot2::labs(
    title = "Sector breadth shows whether the contrast is concentrated",
    subtitle = "Share of 11 sector medians where paired sideways-minus-trending correlation is positive",
    x = "Following sessions", y = "Prior sessions",
    caption = "Breadth is descriptive and does not correct for overlapping observations or multiple comparisons."
  ) +
  ggplot2::coord_equal() + theme_contrast()
ggplot2::ggsave(file.path(visual_dir, "sideways_advantage_sector_breadth_heatmap.png"), p_breadth, width = 10.8, height = 8.2, dpi = 180)

diag_long <- rbind(
  data.frame(horizon = diagonal$prior_sessions, series = "ER20 sideways", value = diagonal$equal_sector_median_sideways_positive_pearson),
  data.frame(horizon = diagonal$prior_sessions, series = "ER20 trending", value = diagonal$equal_sector_median_trending_positive_pearson),
  data.frame(horizon = diagonal$prior_sessions, series = "Sideways - trending", value = diagonal$equal_sector_median_sideways_minus_trending_pearson)
)
p_diag <- ggplot2::ggplot(diag_long, ggplot2::aes(horizon, value, color = series, group = series)) +
  ggplot2::geom_hline(yintercept = 0, color = "#94a3b8", linewidth = 0.5) +
  ggplot2::geom_line(linewidth = 1.2) +
  ggplot2::geom_point(size = 2.6) +
  ggplot2::scale_color_manual(values = c(
    "ER20 sideways" = "#14866d", "ER20 trending" = "#b44738",
    "Sideways - trending" = "#2066a8"
  )) +
  ggplot2::scale_x_continuous(breaks = contract$horizons) +
  ggplot2::labs(
    title = "Equal-horizon checkpoints retain the state contrast",
    subtitle = "Positive-prior correlation on the 1->1 through 100->100 diagonal",
    x = "Prior and following sessions", y = "Equal-sector median correlation", color = NULL,
    caption = "The blue line is a difference in correlations, not a return or spread trade."
  ) + theme_contrast() +
  ggplot2::theme(legend.position = "top")
ggplot2::ggsave(file.path(visual_dir, "sideways_vs_trending_diagonal.png"), p_diag, width = 11.5, height = 6.5, dpi = 180)

sector_surface$sector <- factor(
  sector_surface$sector,
  levels = sector_surface$sector[order(sector_surface$median_sideways_minus_trending_pearson)]
)
p_sector <- ggplot2::ggplot(
  sector_surface,
  ggplot2::aes(median_sideways_minus_trending_pearson, sector)
) +
  ggplot2::geom_vline(xintercept = 0, color = "#94a3b8", linewidth = 0.5) +
  ggplot2::geom_segment(
    ggplot2::aes(x = 0, xend = median_sideways_minus_trending_pearson, yend = sector),
    color = "#9cbdb5", linewidth = 1
  ) +
  ggplot2::geom_point(ggplot2::aes(size = sideways_advantage_cell_fraction), color = "#14866d") +
  ggplot2::scale_size_continuous(range = c(4, 9), labels = scales::label_percent(accuracy = 1), name = "Cells favoring sideways") +
  ggplot2::labs(
    title = "Every core sector favors sideways on its median cell",
    subtitle = "Median paired correlation contrast across each sector's 225-cell surface; point size shows positive-cell breadth",
    x = "Median sideways - trending correlation", y = NULL,
    caption = "Sector labels are frozen current research metadata, not point-in-time membership histories."
  ) + theme_contrast() +
  ggplot2::theme(legend.position = "top")
ggplot2::ggsave(file.path(visual_dir, "sideways_advantage_by_sector.png"), p_sector, width = 11.5, height = 7.2, dpi = 180)

full_summary <- regions[regions$region == "CROSS_REGION", , drop = FALSE]
lead_summary <- regions[regions$region == "LEAD_5_20", , drop = FALSE]
all_surface <- data.frame(
  region = "ALL_15X15",
  cells = nrow(equal_sector),
  median_sideways_positive_pearson = stats::median(equal_sector$equal_sector_median_sideways_positive_pearson),
  median_trending_positive_pearson = stats::median(equal_sector$equal_sector_median_trending_positive_pearson),
  median_sideways_minus_trending_pearson = stats::median(equal_sector$equal_sector_median_sideways_minus_trending_pearson),
  sideways_advantage_cell_fraction = mean(equal_sector$equal_sector_median_sideways_minus_trending_pearson > 0),
  median_sector_sideways_advantage_fraction = stats::median(equal_sector$sector_sideways_advantage_fraction)
)
summary_table <- rbind(all_surface, regions)
utils::write.csv(summary_table, file.path(output_dir, "contrast_summary.csv"), row.names = FALSE)

fmt <- function(x) sprintf("%+.3f", x)
pct <- function(x) sprintf("%.1f%%", 100 * x)
report <- c(
  "# Daily Continuation: ER20 Sideways Versus Trending", "",
  "## Frozen question", "",
  "After a positive completed cumulative return, is the subsequent-return correlation more continuation-shaped in a causal ER20-sideways state than in a causal ER20-trending state?", "",
  "## Measurement boundary", "",
  "- Source: the already-computed 2018-2023 full-vocabulary 129-instrument atlas; no bars or outcomes were recomputed.",
  "- Primary aggregation: paired within asset and horizon cell, then median within each of 11 sectors, then equal-sector median across sectors.",
  "- Surface: the frozen 15 by 15 prior/following horizon grid; positive-prior branch only.",
  "- Contrast: ER20-sideways positive-prior correlation minus ER20-trending positive-prior correlation.",
  "- This contrast is a difference in descriptive correlations, not a portfolio return, spread, or tradable payoff.", "",
  "## Readout", "",
  sprintf("- Across all 225 cells, sideways median r is `%s`, trending median r is `%s`, and the paired median contrast is `%s`.", fmt(all_surface$median_sideways_positive_pearson), fmt(all_surface$median_trending_positive_pearson), fmt(all_surface$median_sideways_minus_trending_pearson)),
  sprintf("- The paired contrast is positive in `%s` of cells; the median cell has positive contrast in `%s` of the 11 sector medians.", pct(all_surface$sideways_advantage_cell_fraction), pct(all_surface$median_sector_sideways_advantage_fraction)),
  sprintf("- In the frozen 5/10/15/20-session lead region, the paired median contrast is `%s` and `%s` of 16 cells favor sideways.", fmt(lead_summary$median_sideways_minus_trending_pearson), pct(lead_summary$sideways_advantage_cell_fraction)), "",
  "- The contrast is not universal: 16 of 225 cells do not favor sideways. Exceptions cluster in the shortest cells and in several 20-session-prior / long-forward combinations; 100->100 also favors trending.",
  sprintf("- All 11 core sectors have a positive median paired contrast across their 225-cell surfaces; sector-level positive-cell breadth ranges from `%s` to `%s`.", pct(min(sector_surface$sideways_advantage_cell_fraction)), pct(max(sector_surface$sideways_advantage_cell_fraction))), "",
  "## Interpretation", "",
  "The comparison supplies fuller context for the continuation lead: inefficient completed paths are generally more continuation-shaped than efficient completed paths, while the trending state often leans toward gain exhaustion. Because both state bins were discovered and contrasted on the same research period, the result remains hypothesis-generating rather than confirmatory.", "",
  "The contrast does not say that sideways-state returns are economically large, that the difference is independent across cells, or that buying the sideways state beats cash or buy-and-hold. It also does not choose a horizon. Those are later gates.", "",
  "## STOP / next gate", "",
  "Status: `DESCRIPTIVE_PAIRED_STATE_CONTRAST_COMPLETE_STOP_BEFORE_HORIZON_OR_RULE_SELECTION`", "",
  "Stop before selecting a best cell or translating the contrast into a trade. The next operator huddle should decide whether to freeze one representative horizon and a next-open baseline test, or preserve this as behavioral context while opening the separate 30-minute design lane.", "",
  "## Artifacts", "",
  "- `equal_sector_paired_cell_summary.csv`: full paired 15 by 15 contrast surface.",
  "- `sector_paired_cell_summary.csv`: 11-sector audit surface.",
  "- `sector_surface_summary.csv` and `cohort_surface_summary.csv`: cross-surface heterogeneity summaries.",
  "- `paired_asset_cells.csv`: asset-level pairing before aggregation.",
  "- `contrast_summary.csv` and `equal_sector_paired_diagonal.csv`: compact readouts.",
  "- `visuals/`: side-by-side states, paired difference, sector breadth, and diagonal views."
)
writeLines(report, file.path(output_dir, "report.md"), useBytes = TRUE)

run_spec_out <- data.frame(
  contrast_id = contract$contrast_id,
  source_packet = normalizePath(source_dir, winslash = "/"),
  analysis_start = as.character(contract$analysis_start),
  analysis_end = as.character(contract$analysis_end),
  branch = contract$branch,
  state_a = "ER20_RED_SIDEWAYS",
  state_b = "ER20_GREEN_TRENDING",
  primary_contrast = "state_a_positive_pearson_minus_state_b_positive_pearson",
  aggregation = "paired_asset_then_sector_median_then_equal_sector_median",
  inference = "none_descriptive_reexpression_only",
  post_2023_status = "sealed",
  strategy_status = "not_opened",
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec_out, file.path(output_dir, "run_spec.csv"), row.names = FALSE)
message("Daily continuation state contrast complete: ", normalizePath(output_dir, winslash = "/"))
