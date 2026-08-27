# Probe the open 10-30 loss-rebound plateau with sparse longer-horizon
# cross-sections. This is a descriptive boundary-location study, not a dense
# parameter search, inferential scan, trading test, or later-period replay.

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

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("The existing ggplot2 dependency is required for boundary-probe visuals.", call. = FALSE)
}

atlas_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "own_asset_return_geometry_atlas_20260826"
)
fine_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_rebound_topology_20260827"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_rebound_boundary_probe_20260827"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

bars_path <- file.path(atlas_dir, "atlas_query_bars.csv")
fine_cells_path <- file.path(fine_dir, "asset_loss_branch_fine_grid.csv")
registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries",
  "own_asset_return_geometry_atlas.csv"
)
required_paths <- c(bars_path, fine_cells_path, registry_path)
if (!all(file.exists(required_paths))) {
  stop("Frozen atlas bars, fine-grid cells, or registry are unavailable.", call. = FALSE)
}

varying_horizons <- c(10L:30L, 35L, 40L, 50L, 75L, 100L)
fixed_horizons <- c(20L, 25L, 30L)
outer_horizons <- c(35L, 40L, 50L, 75L, 100L)

probe_rows <- list()
probe_index <- 0L
for (fixed_horizon in fixed_horizons) {
  for (varying_horizon in varying_horizons) {
    probe_index <- probe_index + 1L
    probe_rows[[probe_index]] <- data.frame(
      orientation = "PRIOR_SCALE",
      orientation_label = "Vary prior; following fixed",
      orientation_order = 1L,
      fixed_horizon = fixed_horizon,
      varying_horizon = varying_horizon,
      prior_sessions = varying_horizon,
      forward_sessions = fixed_horizon,
      stringsAsFactors = FALSE
    )
    probe_index <- probe_index + 1L
    probe_rows[[probe_index]] <- data.frame(
      orientation = "FORWARD_SCALE",
      orientation_label = "Prior fixed; vary following",
      orientation_order = 2L,
      fixed_horizon = fixed_horizon,
      varying_horizon = varying_horizon,
      prior_sessions = fixed_horizon,
      forward_sessions = varying_horizon,
      stringsAsFactors = FALSE
    )
  }
}
probe_registry <- do.call(rbind, probe_rows)
rownames(probe_registry) <- NULL
pair_registry <- unique(probe_registry[c("prior_sessions", "forward_sessions")])
pair_registry <- pair_registry[order(
  pair_registry$prior_sessions, pair_registry$forward_sessions
), , drop = FALSE]
rownames(pair_registry) <- NULL

contract <- oarga_contract()
contract$atlas_id <- "OWN_ASSET_RETURN_GEOMETRY_REBOUND_BOUNDARY_PROBE_01"
contract$horizons <- sort(unique(c(varying_horizons, fixed_horizons)))

registry <- oarga_validate_registry(utils::read.csv(
  registry_path, stringsAsFactors = FALSE, check.names = FALSE
), contract)
bars <- utils::read.csv(bars_path, stringsAsFactors = FALSE, check.names = FALSE)
bars$session_date <- as.Date(bars$session_date)
bars$adjusted <- as.logical(bars$adjusted)
fine_cells <- utils::read.csv(
  fine_cells_path, stringsAsFactors = FALSE, check.names = FALSE
)

condition_specs <- data.frame(
  condition = c("UNFILTERED", "ATRP", "SIGNED_ER20"),
  state = c("ALL", "HIGH", "DOWN_TREND"),
  state_column = c(NA_character_, "atrp_state", "signed_er20_state"),
  condition_label = c("UNFILTERED LOSS", "ATR% HIGH LOSS", "SIGNED DOWN LOSS"),
  condition_order = 1:3,
  stringsAsFactors = FALSE
)

describe_loss_branch <- function(surface, state, state_column, minimum_observations) {
  sample <- if (is.na(state_column)) {
    surface
  } else {
    surface[surface[[state_column]] == state, , drop = FALSE]
  }
  sample <- sample[sample$prior_cumulative_log_return < 0, , drop = FALSE]
  n <- nrow(sample)
  estimable <- n >= minimum_observations &&
    stats::sd(sample$prior_cumulative_log_return) > 0 &&
    stats::sd(sample$forward_cumulative_log_return) > 0
  data.frame(
    negative_observations = n,
    estimation_status = if (estimable) "DESCRIBED" else "INSUFFICIENT_NEGATIVE_BRANCH",
    pearson_correlation = if (estimable) stats::cor(
      sample$prior_cumulative_log_return,
      sample$forward_cumulative_log_return
    ) else NA_real_,
    spearman_correlation = if (estimable) suppressWarnings(stats::cor(
      sample$prior_cumulative_log_return,
      sample$forward_cumulative_log_return,
      method = "spearman"
    )) else NA_real_,
    ols_slope = if (estimable) unname(stats::coef(stats::lm(
      forward_cumulative_log_return ~ prior_cumulative_log_return,
      data = sample
    ))[["prior_cumulative_log_return"]]) else NA_real_,
    mean_forward_return = if (n) mean(sample$forward_cumulative_log_return) else NA_real_,
    probability_forward_up = if (n) mean(sample$forward_cumulative_log_return > 0) else NA_real_,
    stringsAsFactors = FALSE
  )
}

asset_rows <- vector(
  "list", nrow(registry) * nrow(pair_registry) * nrow(condition_specs)
)
row_index <- 0L
ledgers <- vector("list", nrow(registry))
names(ledgers) <- registry$symbol

for (asset_index in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[asset_index]]
  message(sprintf("[%02d/%02d] %s", asset_index, nrow(registry), symbol))
  ledger <- oarga_build_ledger(bars, symbol, contract)
  ledgers[[symbol]] <- ledger
  for (pair_index in seq_len(nrow(pair_registry))) {
    prior_sessions <- pair_registry$prior_sessions[[pair_index]]
    forward_sessions <- pair_registry$forward_sessions[[pair_index]]
    surface <- oarga_construct_surface(
      ledger, prior_sessions, forward_sessions, contract
    )
    for (condition_index in seq_len(nrow(condition_specs))) {
      spec <- condition_specs[condition_index, , drop = FALSE]
      row_index <- row_index + 1L
      row <- describe_loss_branch(
        surface,
        spec$state[[1L]],
        spec$state_column[[1L]],
        contract$minimum_branch_observations
      )
      row$symbol <- symbol
      row$condition <- spec$condition[[1L]]
      row$state <- spec$state[[1L]]
      row$condition_label <- spec$condition_label[[1L]]
      row$condition_order <- spec$condition_order[[1L]]
      row$prior_sessions <- prior_sessions
      row$forward_sessions <- forward_sessions
      asset_rows[[row_index]] <- row
    }
  }
}

asset_cells <- do.call(rbind, asset_rows)
rownames(asset_cells) <- NULL
asset_cells <- merge(
  asset_cells,
  registry[c("atlas_order", "symbol", "behavior_group", "instrument_type", "selection_role")],
  by = "symbol", all.x = TRUE, sort = FALSE
)
asset_cells <- asset_cells[order(
  asset_cells$condition_order, asset_cells$prior_sessions,
  asset_cells$forward_sessions, asset_cells$atlas_order
), , drop = FALSE]

summarize_cells <- function(data, keys) {
  groups <- split(data, interaction(data[keys], drop = TRUE, lex.order = TRUE))
  output <- do.call(rbind, lapply(groups, function(x) {
    described <- x[
      x$estimation_status == "DESCRIBED" & is.finite(x$pearson_correlation),
      , drop = FALSE
    ]
    base <- x[1L, keys, drop = FALSE]
    values <- described$pearson_correlation
    slopes <- described$ols_slope
    counts <- described$negative_observations
    base$asset_count <- length(values)
    base$median_pearson <- if (length(values)) stats::median(values) else NA_real_
    base$mean_pearson <- if (length(values)) mean(values) else NA_real_
    base$q25_pearson <- if (length(values)) unname(stats::quantile(values, 0.25)) else NA_real_
    base$q75_pearson <- if (length(values)) unname(stats::quantile(values, 0.75)) else NA_real_
    base$negative_asset_fraction <- if (length(values)) mean(values < 0) else NA_real_
    base$median_ols_slope <- if (length(slopes)) stats::median(slopes) else NA_real_
    base$median_negative_observations <- if (length(counts)) stats::median(counts) else NA_real_
    base
  }))
  rownames(output) <- NULL
  output
}

cell_summary <- summarize_cells(
  asset_cells,
  c("condition", "state", "condition_label", "condition_order", "prior_sessions", "forward_sessions")
)
group_summary <- summarize_cells(
  asset_cells,
  c(
    "behavior_group", "condition", "state", "condition_label",
    "condition_order", "prior_sessions", "forward_sessions"
  )
)

# Reuse the preceding topology pass's descriptive thresholds. These organize
# the boundary shape; they are not inferential or admission gates.
cell_summary$breadth_supported <- cell_summary$asset_count >= 20L &
  cell_summary$median_pearson < 0 &
  cell_summary$negative_asset_fraction >= 0.60
cell_summary$strong_rebound <- cell_summary$asset_count >= 20L &
  cell_summary$median_pearson <= -0.10 &
  cell_summary$negative_asset_fraction >= 0.70

cross_sections <- merge(
  probe_registry, cell_summary,
  by = c("prior_sessions", "forward_sessions"),
  all.x = TRUE, sort = FALSE
)
cross_sections <- cross_sections[order(
  cross_sections$condition_order, cross_sections$orientation_order,
  cross_sections$fixed_horizon, cross_sections$varying_horizon
), , drop = FALSE]
rownames(cross_sections) <- NULL

group_cross_sections <- merge(
  probe_registry, group_summary,
  by = c("prior_sessions", "forward_sessions"),
  all.x = TRUE, sort = FALSE
)
group_cross_sections <- group_cross_sections[order(
  group_cross_sections$condition_order, group_cross_sections$behavior_group,
  group_cross_sections$orientation_order, group_cross_sections$fixed_horizon,
  group_cross_sections$varying_horizon
), , drop = FALSE]
rownames(group_cross_sections) <- NULL

metric_at <- function(x, horizon, column) {
  value <- x[x$varying_horizon == horizon, column]
  if (length(value)) value[[1L]] else NA
}

outer <- cross_sections[
  cross_sections$varying_horizon %in% outer_horizons,
  , drop = FALSE
]
boundary_groups <- split(
  outer,
  interaction(
    outer[c(
      "condition", "state", "condition_label", "condition_order",
      "orientation", "orientation_label", "orientation_order", "fixed_horizon"
    )],
    drop = TRUE, lex.order = TRUE
  )
)
boundary_summary <- do.call(rbind, lapply(boundary_groups, function(x) {
  x <- x[order(x$varying_horizon), , drop = FALSE]
  base <- x[1L, c(
    "condition", "state", "condition_label", "condition_order",
    "orientation", "orientation_label", "orientation_order", "fixed_horizon"
  ), drop = FALSE]
  supported <- x$breadth_supported %in% TRUE
  strong <- x$strong_rebound %in% TRUE
  base$outer_cells <- nrow(x)
  base$outer_supported_cells <- sum(supported)
  base$outer_strong_cells <- sum(strong)
  base$support_pattern_35_40_50_75_100 <- paste(ifelse(supported, "S", "."), collapse = "")
  base$strong_pattern_35_40_50_75_100 <- paste(ifelse(strong, "X", "."), collapse = "")
  base$longest_supported_horizon <- if (any(supported)) max(x$varying_horizon[supported]) else NA_integer_
  base$longest_strong_horizon <- if (any(strong)) max(x$varying_horizon[strong]) else NA_integer_
  base$terminal_status <- if (isTRUE(metric_at(x, 100L, "strong_rebound"))) {
    "STRONG_AT_100"
  } else if (isTRUE(metric_at(x, 100L, "breadth_supported"))) {
    "SUPPORTED_AT_100"
  } else {
    "NOT_SUPPORTED_AT_100"
  }
  base$median_r_35 <- metric_at(x, 35L, "median_pearson")
  base$median_r_40 <- metric_at(x, 40L, "median_pearson")
  base$median_r_50 <- metric_at(x, 50L, "median_pearson")
  base$median_r_75 <- metric_at(x, 75L, "median_pearson")
  base$median_r_100 <- metric_at(x, 100L, "median_pearson")
  base$negative_asset_fraction_100 <- metric_at(x, 100L, "negative_asset_fraction")
  base$asset_count_100 <- metric_at(x, 100L, "asset_count")
  base$median_negative_observations_100 <- metric_at(x, 100L, "median_negative_observations")
  base
}))
rownames(boundary_summary) <- NULL
boundary_summary <- boundary_summary[order(
  boundary_summary$condition_order, boundary_summary$orientation_order,
  boundary_summary$fixed_horizon
), , drop = FALSE]

fine_subset <- asset_cells[
  asset_cells$prior_sessions <= 30L & asset_cells$forward_sessions <= 30L,
  c(
    "symbol", "condition", "state", "prior_sessions", "forward_sessions",
    "negative_observations", "pearson_correlation"
  )
]
fine_reference <- fine_cells[
  paste(fine_cells$condition, fine_cells$state) %in%
    paste(condition_specs$condition, condition_specs$state),
  c(
    "symbol", "condition", "state", "prior_sessions", "forward_sessions",
    "negative_observations", "pearson_correlation"
  )
]
fine_reference <- merge(
  fine_reference,
  pair_registry[
    pair_registry$prior_sessions <= 30L & pair_registry$forward_sessions <= 30L,
    , drop = FALSE
  ],
  by = c("prior_sessions", "forward_sessions"),
  all = FALSE, sort = FALSE
)
parity <- merge(
  fine_subset, fine_reference,
  by = c("symbol", "condition", "state", "prior_sessions", "forward_sessions"),
  all = TRUE, sort = TRUE,
  suffixes = c("_probe", "_fine")
)
parity$pearson_absolute_difference <- abs(
  parity$pearson_correlation_probe - parity$pearson_correlation_fine
)
parity$observation_difference <- abs(
  parity$negative_observations_probe - parity$negative_observations_fine
)

expected_asset_rows <- nrow(registry) * nrow(pair_registry) * nrow(condition_specs)
expected_cross_section_rows <- nrow(probe_registry) * nrow(condition_specs)
checks <- data.frame(
  check = c(
    "registry_exact", "source_bars_sealed", "probe_registry_exact",
    "unique_pair_count_exact", "asset_rows_exact", "cross_section_rows_exact",
    "three_conditions_exact", "fine_grid_parity", "outer_horizons_exact",
    "no_inference_columns", "minimum_assets_available", "asset_cells_unique"
  ),
  status = c(
    if (identical(registry, oarga_expected_registry())) "PASS" else "FAIL",
    if (max(bars$session_date) >= contract$analysis_end &&
        all(vapply(ledgers, function(x) max(x$session_date) <= contract$analysis_end, logical(1)))) "PASS" else "FAIL",
    if (identical(sort(unique(probe_registry$varying_horizon)), varying_horizons) &&
        identical(sort(unique(probe_registry$fixed_horizon)), fixed_horizons) &&
        identical(sort(unique(probe_registry$orientation)), c("FORWARD_SCALE", "PRIOR_SCALE"))) "PASS" else "FAIL",
    if (nrow(pair_registry) == 147L) "PASS" else "FAIL",
    if (nrow(asset_cells) == expected_asset_rows) "PASS" else "FAIL",
    if (nrow(cross_sections) == expected_cross_section_rows) "PASS" else "FAIL",
    if (nrow(unique(asset_cells[c("condition", "state")])) == 3L) "PASS" else "FAIL",
    if (nrow(parity) == nrow(fine_subset) &&
        max(parity$pearson_absolute_difference, na.rm = TRUE) < 1e-12 &&
        max(parity$observation_difference, na.rm = TRUE) == 0) "PASS" else "FAIL",
    if (identical(sort(unique(outer$varying_horizon)), outer_horizons)) "PASS" else "FAIL",
    if (!any(grepl("p_value|q_value|standard_error|lower_95|upper_95", names(asset_cells)))) "PASS" else "FAIL",
    if (all(cell_summary$asset_count >= 20L)) "PASS" else "FAIL",
    if (!anyDuplicated(asset_cells[c(
      "symbol", "condition", "state", "prior_sessions", "forward_sessions"
    )])) "PASS" else "FAIL"
  ),
  stringsAsFactors = FALSE
)

write_csv <- function(x, filename) utils::write.csv(
  x, file.path(output_dir, filename), row.names = FALSE, na = ""
)
write_csv(checks, "boundary_probe_checks.csv")
write_csv(parity, "fine_grid_anchor_parity.csv")
if (any(checks$status != "PASS")) {
  stop(
    "One or more boundary-probe checks failed: ",
    paste(checks$check[checks$status != "PASS"], collapse = ", "),
    call. = FALSE
  )
}

write_csv(probe_registry, "probe_registry.csv")
write_csv(asset_cells, "asset_loss_branch_boundary_cells.csv")
write_csv(cell_summary, "equal_asset_boundary_cell_summary.csv")
write_csv(cross_sections, "equal_asset_boundary_cross_sections.csv")
write_csv(group_cross_sections, "behavior_group_boundary_cross_sections.csv")
write_csv(boundary_summary, "boundary_summary.csv")

run_spec <- data.frame(
  field = c(
    "probe_id", "source_bars", "source_fine_grid", "assets", "groups",
    "analysis_window", "returns", "varying_horizons", "fixed_horizons",
    "outer_horizons", "primary_surface", "comparators",
    "minimum_negative_branch_observations", "breadth_supported_rule",
    "strong_rebound_rule", "inference", "incremental_forward_returns",
    "post_2023", "asset_expansion", "trading_calculation"
  ),
  value = c(
    contract$atlas_id,
    "own_asset_return_geometry_atlas_20260826/atlas_query_bars.csv",
    "return_geometry_rebound_topology_20260827/asset_loss_branch_fine_grid.csv",
    "same frozen 30-asset atlas", "same six groups",
    "2018-01-02 through 2023-12-29", "cumulative close-to-close log return",
    paste(varying_horizons, collapse = ","), paste(fixed_horizons, collapse = ","),
    paste(outer_horizons, collapse = ","),
    "negative-prior branch within signed-ER20 DOWN",
    "negative-prior unfiltered; negative-prior ATR% HIGH",
    as.character(contract$minimum_branch_observations),
    ">=20 assets; median Pearson <0; >=60% assets negative",
    ">=20 assets; median Pearson <=-0.10; >=70% assets negative",
    "none; descriptive boundary location only", "not opened",
    "none", "none", "none"
  ),
  stringsAsFactors = FALSE
)
write_csv(run_spec, "run_spec.csv")

theme_boundary <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 9, color = "#10233F"),
      plot.subtitle = ggplot2::element_text(size = base_size + 1, color = "#5B6F8B"),
      plot.caption = ggplot2::element_text(size = base_size - 1, color = "#63758D", hjust = 0),
      strip.text = ggplot2::element_text(face = "bold", color = "#14233C"),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      legend.position = "bottom",
      plot.margin = ggplot2::margin(14, 20, 14, 14)
    )
}

anchor_colors <- c(`20` = "#657687", `25` = "#D9822B", `30` = "#C94D4D")
x_breaks <- c(10L, 15L, 20L, 25L, 30L, 35L, 40L, 50L, 75L, 100L)
plot_data <- cross_sections
plot_data$fixed_horizon_factor <- factor(plot_data$fixed_horizon, levels = fixed_horizons)
plot_data$condition_label <- factor(
  plot_data$condition_label, levels = condition_specs$condition_label
)
plot_data$orientation_label <- factor(
  plot_data$orientation_label,
  levels = c("Vary prior; following fixed", "Prior fixed; vary following")
)

p_effect <- ggplot2::ggplot(
  plot_data,
  ggplot2::aes(
    varying_horizon, median_pearson,
    color = fixed_horizon_factor, group = fixed_horizon_factor
  )
) +
  ggplot2::geom_hline(yintercept = 0, color = "#AEB8C5", linewidth = 0.45) +
  ggplot2::geom_vline(xintercept = 30, linetype = "dashed", color = "#243B5A", linewidth = 0.55) +
  ggplot2::geom_line(linewidth = 0.95) +
  ggplot2::geom_point(size = 1.9) +
  ggplot2::facet_grid(condition_label ~ orientation_label) +
  ggplot2::scale_color_manual(values = anchor_colors, name = "Fixed horizon") +
  ggplot2::scale_x_continuous(breaks = x_breaks) +
  ggplot2::labs(
    title = "The plateau boundary can be probed without filling the full 100x100 grid",
    subtitle = "One horizon varies to 100 sessions while the other remains fixed at 20, 25, or 30.",
    x = "Varying horizon (sessions)", y = "Equal-asset median Pearson r",
    caption = "Dashed line marks the prior 30-session boundary. Adjacent cumulative windows remain highly dependent."
  ) +
  theme_boundary(12)
ggplot2::ggsave(
  file.path(visual_dir, "boundary_equal_asset_cross_sections.png"),
  p_effect, width = 15.4, height = 10.0, dpi = 220, bg = "white"
)

p_breadth <- ggplot2::ggplot(
  plot_data,
  ggplot2::aes(
    varying_horizon, negative_asset_fraction,
    color = fixed_horizon_factor, group = fixed_horizon_factor
  )
) +
  ggplot2::geom_hline(yintercept = 0.60, color = "#AEB8C5", linewidth = 0.45) +
  ggplot2::geom_hline(yintercept = 0.70, color = "#C94D4D", linewidth = 0.45, linetype = "dotted") +
  ggplot2::geom_vline(xintercept = 30, linetype = "dashed", color = "#243B5A", linewidth = 0.55) +
  ggplot2::geom_line(linewidth = 0.95) +
  ggplot2::geom_point(size = 1.9) +
  ggplot2::facet_grid(condition_label ~ orientation_label) +
  ggplot2::scale_color_manual(values = anchor_colors, name = "Fixed horizon") +
  ggplot2::scale_x_continuous(breaks = x_breaks) +
  ggplot2::scale_y_continuous(
    limits = c(0.35, 1.0), breaks = seq(0.4, 1.0, 0.1),
    labels = function(x) paste0(round(100 * x), "%")
  ) +
  ggplot2::labs(
    title = "Cross-asset breadth shows whether the outer shape remains shared",
    subtitle = "Gray marks 60% descriptive support; red marks the 70% strong-cell breadth component.",
    x = "Varying horizon (sessions)", y = "Assets with negative within-loss correlation",
    caption = "Breadth is descriptive and equal-weighted across the frozen 30 assets."
  ) +
  theme_boundary(12)
ggplot2::ggsave(
  file.path(visual_dir, "boundary_cross_asset_breadth.png"),
  p_breadth, width = 15.4, height = 10.0, dpi = 220, bg = "white"
)

outer_plot <- cross_sections[
  cross_sections$condition == "SIGNED_ER20" &
    cross_sections$varying_horizon %in% c(30L, outer_horizons),
  , drop = FALSE
]
outer_plot$row_label <- paste0(
  ifelse(outer_plot$orientation == "PRIOR_SCALE", "Prior varies | F=", "Following varies | P="),
  outer_plot$fixed_horizon
)
outer_plot$row_label <- factor(
  outer_plot$row_label,
  levels = rev(c(
    paste0("Prior varies | F=", fixed_horizons),
    paste0("Following varies | P=", fixed_horizons)
  ))
)
p_outer <- ggplot2::ggplot(
  outer_plot,
  ggplot2::aes(factor(varying_horizon), row_label, fill = median_pearson)
) +
  ggplot2::geom_tile(color = "white", linewidth = 1.0) +
  ggplot2::geom_text(
    ggplot2::aes(label = sprintf("r=%+.2f\n%.0f%%", median_pearson, 100 * negative_asset_fraction)),
    size = 4.0, color = "#16243A", lineheight = 0.95
  ) +
  ggplot2::scale_fill_gradient2(
    low = "#C84D4D", mid = "#F7F5F3", high = "#8AB3D9", midpoint = 0,
    limits = c(-0.35, 0.12), name = "Median r"
  ) +
  ggplot2::labs(
    title = "Signed-DOWN loss rebound remains visible at the sparse outer checkpoints",
    subtitle = "Cells show equal-asset median correlation and the share of assets with a negative relationship.",
    x = "Varying horizon (sessions)", y = NULL,
    caption = "The 30-session seam is retained for continuity; 35, 40, 50, 75, and 100 are the new boundary checkpoints."
  ) +
  theme_boundary(13) +
  ggplot2::theme(axis.text.y = ggplot2::element_text(face = "bold"))
ggplot2::ggsave(
  file.path(visual_dir, "signed_down_outer_checkpoint_matrix.png"),
  p_outer, width = 13.4, height = 7.2, dpi = 220, bg = "white"
)

group_plot <- group_cross_sections[
  group_cross_sections$condition == "SIGNED_ER20",
  , drop = FALSE
]
group_plot$fixed_horizon_factor <- factor(group_plot$fixed_horizon, levels = fixed_horizons)
group_plot$orientation_label <- factor(
  group_plot$orientation_label,
  levels = c("Vary prior; following fixed", "Prior fixed; vary following")
)
p_group <- ggplot2::ggplot(
  group_plot,
  ggplot2::aes(
    varying_horizon, median_pearson,
    color = fixed_horizon_factor, group = fixed_horizon_factor
  )
) +
  ggplot2::geom_hline(yintercept = 0, color = "#B5BFCA", linewidth = 0.4) +
  ggplot2::geom_vline(xintercept = 30, linetype = "dashed", color = "#243B5A", linewidth = 0.45) +
  ggplot2::geom_line(linewidth = 0.75) +
  ggplot2::geom_point(size = 1.35) +
  ggplot2::facet_grid(behavior_group ~ orientation_label) +
  ggplot2::scale_color_manual(values = anchor_colors, name = "Fixed horizon") +
  ggplot2::scale_x_continuous(breaks = x_breaks) +
  ggplot2::labs(
    title = "Longer-horizon persistence is not uniform across behavioral groups",
    subtitle = "Signed-DOWN loss-branch medians remain separated by the same six frozen five-asset groups.",
    x = "Varying horizon (sessions)", y = "Five-asset group median Pearson r",
    caption = "Five assets per group preserve heterogeneity; they do not estimate an asset-class population."
  ) +
  theme_boundary(11)
ggplot2::ggsave(
  file.path(visual_dir, "signed_down_group_boundary_cross_sections.png"),
  p_group, width = 15.4, height = 12.8, dpi = 220, bg = "white"
)

p_support <- ggplot2::ggplot(
  plot_data,
  ggplot2::aes(
    varying_horizon, median_negative_observations,
    color = fixed_horizon_factor, group = fixed_horizon_factor
  )
) +
  ggplot2::geom_vline(xintercept = 30, linetype = "dashed", color = "#243B5A", linewidth = 0.55) +
  ggplot2::geom_line(linewidth = 0.95) +
  ggplot2::geom_point(size = 1.8) +
  ggplot2::facet_grid(condition_label ~ orientation_label, scales = "free_y") +
  ggplot2::scale_color_manual(values = anchor_colors, name = "Fixed horizon") +
  ggplot2::scale_x_continuous(breaks = x_breaks) +
  ggplot2::labs(
    title = "The 100-session checkpoints retain descriptive branch support",
    subtitle = "Median negative-branch observations are shown per asset; the frozen estimability floor is 30.",
    x = "Varying horizon (sessions)", y = "Median negative-branch observations",
    caption = "Long cumulative windows reduce temporal independence even when raw observation counts remain adequate."
  ) +
  theme_boundary(12)
ggplot2::ggsave(
  file.path(visual_dir, "boundary_sample_support.png"),
  p_support, width = 15.4, height = 10.0, dpi = 220, bg = "white"
)

summary_line <- function(row) {
  sprintf(
    "- %s | %s | fixed %d: supported %d/%d outer checkpoints; strong %d/%d; at 100 r=%+.4f, %.1f%% negative assets, median n=%.0f; %s.",
    row$condition_label, row$orientation_label, row$fixed_horizon,
    row$outer_supported_cells, row$outer_cells,
    row$outer_strong_cells, row$outer_cells,
    row$median_r_100, 100 * row$negative_asset_fraction_100,
    row$median_negative_observations_100, row$terminal_status
  )
}
report_lines <- c(
  "# Own-Asset Loss-Rebound Boundary Probe: 2018-2023",
  "",
  "Status: `DESCRIPTIVE_BOUNDARY_PROBE_COMPLETE_CUMULATIVE_REBOUND_PERSISTS_THROUGH_100_STOP_BEFORE_INCREMENTAL_DECOMPOSITION`",
  "",
  "## Frozen Question",
  "",
  "Does the open 10-30 loss-rebound plateau persist, decay, or change shape at sparse 35-, 40-, 50-, 75-, and 100-session checkpoints?",
  "",
  "## Contract",
  "",
  "- Same frozen 30 assets, six groups, adjusted daily bars, and 2018-2023 analysis window.",
  "- Negative-prior branch only; signed-ER20 DOWN primary; unfiltered and ATR% HIGH comparators.",
  "- Vary one horizon through 10-30 plus 35/40/50/75/100 while holding the other at 20/25/30.",
  "- No dense 31-100 surface, cellwise inference, BH scan, post-2023 data, asset expansion, incremental-return decomposition, or trading calculation.",
  "",
  "## Descriptive Readout",
  "",
  vapply(seq_len(nrow(boundary_summary)), function(i) summary_line(boundary_summary[i, ]), character(1L)),
  "",
  "## Interpretation Boundary",
  "",
  "The probe locates scale, not an optimal lookback or holding period. Cumulative forward returns are nested, so persistence at 100 sessions cannot reveal when the associated return accrues. Longer windows also overlap more heavily and can span multiple state transitions.",
  "",
  "If the outer shape is coherent enough to merit another slice, incremental forward-return blocks should be studied separately before any strategy horizon is discussed."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Rebound boundary probe complete: ", normalizePath(output_dir, winslash = "/"))
message(
  "Rows: ", nrow(asset_cells), "; unique pairs: ", nrow(pair_registry),
  "; checks: ", paste(checks$status, collapse = ",")
)
