# Map the previously transported loss-rebound neighborhood at one-session
# resolution. This is a descriptive topology pass over the frozen 2018-2023
# atlas, not a new inferential scan, parameter optimizer, or trading test.

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
  stop("The existing ggplot2 dependency is required for topology visuals.", call. = FALSE)
}

source_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "own_asset_return_geometry_atlas_20260826"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_rebound_topology_20260827"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)

bars_path <- file.path(source_dir, "atlas_query_bars.csv")
coarse_path <- file.path(source_dir, "asset_prior_sign_cells.csv")
registry_path <- file.path(
  repo_root, "operator_hypothesis_lab", "registries",
  "own_asset_return_geometry_atlas.csv"
)
required_paths <- c(bars_path, coarse_path, registry_path)
if (!all(file.exists(required_paths))) {
  stop("The frozen atlas bars, coarse cells, or registry are unavailable.", call. = FALSE)
}

contract <- oarga_contract()
contract$atlas_id <- "OWN_ASSET_RETURN_GEOMETRY_REBOUND_TOPOLOGY_01"
contract$horizons <- 10L:30L

registry <- oarga_validate_registry(utils::read.csv(
  registry_path, stringsAsFactors = FALSE, check.names = FALSE
), contract)
bars <- utils::read.csv(bars_path, stringsAsFactors = FALSE, check.names = FALSE)
bars$session_date <- as.Date(bars$session_date)
bars$adjusted <- as.logical(bars$adjusted)
coarse <- utils::read.csv(coarse_path, stringsAsFactors = FALSE, check.names = FALSE)

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

asset_rows <- vector("list", nrow(registry) * length(contract$horizons)^2L * nrow(condition_specs))
row_index <- 0L
ledgers <- vector("list", nrow(registry))
names(ledgers) <- registry$symbol

for (asset_index in seq_len(nrow(registry))) {
  symbol <- registry$symbol[[asset_index]]
  message(sprintf("[%02d/%02d] %s", asset_index, nrow(registry), symbol))
  ledger <- oarga_build_ledger(bars, symbol, contract)
  ledgers[[symbol]] <- ledger
  for (prior_sessions in contract$horizons) {
    for (forward_sessions in contract$horizons) {
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
    described <- x[x$estimation_status == "DESCRIBED" & is.finite(x$pearson_correlation), , drop = FALSE]
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

# Catalog thresholds are descriptive and frozen before this fine grid is read.
# Breadth-supported: >=20 assets, negative median, >=60% negative assets.
# Strong: >=20 assets, median r <= -0.10, >=70% negative assets.
cell_summary$breadth_supported <- cell_summary$asset_count >= 20L &
  cell_summary$median_pearson < 0 &
  cell_summary$negative_asset_fraction >= 0.60
cell_summary$strong_rebound <- cell_summary$asset_count >= 20L &
  cell_summary$median_pearson <= -0.10 &
  cell_summary$negative_asset_fraction >= 0.70

largest_component <- function(x, flag_column) {
  active <- x[[flag_column]] %in% TRUE
  coords <- x[active, c("prior_sessions", "forward_sessions"), drop = FALSE]
  if (!nrow(coords)) {
    return(data.frame(
      component_cells = 0L, prior_min = NA_integer_, prior_max = NA_integer_,
      forward_min = NA_integer_, forward_max = NA_integer_,
      touches_boundary = FALSE, stringsAsFactors = FALSE
    ))
  }
  keys <- paste(coords$prior_sessions, coords$forward_sessions, sep = ":")
  unvisited <- setNames(rep(TRUE, length(keys)), keys)
  components <- list()
  while (any(unvisited)) {
    seed <- names(unvisited)[which(unvisited)[[1L]]]
    queue <- seed
    unvisited[[seed]] <- FALSE
    component <- character()
    while (length(queue)) {
      current <- queue[[1L]]
      queue <- queue[-1L]
      component <- c(component, current)
      parts <- as.integer(strsplit(current, ":", fixed = TRUE)[[1L]])
      neighbors <- c(
        paste(parts[[1L]] - 1L, parts[[2L]], sep = ":"),
        paste(parts[[1L]] + 1L, parts[[2L]], sep = ":"),
        paste(parts[[1L]], parts[[2L]] - 1L, sep = ":"),
        paste(parts[[1L]], parts[[2L]] + 1L, sep = ":")
      )
      present_neighbors <- neighbors[neighbors %in% names(unvisited)]
      new_neighbors <- present_neighbors[unvisited[present_neighbors]]
      if (length(new_neighbors)) {
        unvisited[new_neighbors] <- FALSE
        queue <- c(queue, new_neighbors)
      }
    }
    components[[length(components) + 1L]] <- component
  }
  largest <- components[[which.max(lengths(components))]]
  matrix_coords <- do.call(rbind, strsplit(largest, ":", fixed = TRUE))
  matrix_coords <- matrix(as.integer(matrix_coords), ncol = 2L)
  prior_min <- min(matrix_coords[, 1L]); prior_max <- max(matrix_coords[, 1L])
  forward_min <- min(matrix_coords[, 2L]); forward_max <- max(matrix_coords[, 2L])
  data.frame(
    component_cells = length(largest),
    prior_min = prior_min, prior_max = prior_max,
    forward_min = forward_min, forward_max = forward_max,
    touches_boundary = prior_min == min(contract$horizons) ||
      prior_max == max(contract$horizons) ||
      forward_min == min(contract$horizons) ||
      forward_max == max(contract$horizons),
    stringsAsFactors = FALSE
  )
}

topology_rows <- lapply(seq_len(nrow(condition_specs)), function(i) {
  spec <- condition_specs[i, , drop = FALSE]
  x <- cell_summary[
    cell_summary$condition == spec$condition[[1L]] &
      cell_summary$state == spec$state[[1L]],
    , drop = FALSE
  ]
  strong_component <- largest_component(x, "strong_rebound")
  supported_component <- largest_component(x, "breadth_supported")
  weights <- pmax(-x$median_pearson, 0)
  strongest <- x[which.min(x$median_pearson), , drop = FALSE]
  center <- x[x$prior_sessions == 20L & x$forward_sessions == 20L, , drop = FALSE]
  p20_row <- x[x$prior_sessions == 20L, , drop = FALSE]
  p20_adjacent <- x[x$prior_sessions %in% c(19L, 21L), , drop = FALSE]
  f20_column <- x[x$forward_sessions == 20L, , drop = FALSE]
  f20_adjacent <- x[x$forward_sessions %in% c(19L, 21L), , drop = FALSE]
  classification <- if (strong_component$component_cells == 0L) {
    "NO_STRONG_COMPONENT"
  } else if (strong_component$touches_boundary) {
    "OPEN_PLATEAU_OR_RIDGE"
  } else if (strong_component$component_cells >= 25L) {
    "BOUNDED_ISLAND"
  } else {
    "LOCAL_CLUSTER"
  }
  data.frame(
    condition = spec$condition[[1L]], state = spec$state[[1L]],
    condition_label = spec$condition_label[[1L]],
    eligible_cells = nrow(x),
    breadth_supported_cells = sum(x$breadth_supported),
    strong_rebound_cells = sum(x$strong_rebound),
    breadth_supported_fraction = mean(x$breadth_supported),
    strong_rebound_fraction = mean(x$strong_rebound),
    largest_supported_component_cells = supported_component$component_cells,
    largest_strong_component_cells = strong_component$component_cells,
    strong_component_prior_min = strong_component$prior_min,
    strong_component_prior_max = strong_component$prior_max,
    strong_component_forward_min = strong_component$forward_min,
    strong_component_forward_max = strong_component$forward_max,
    strong_component_touches_boundary = strong_component$touches_boundary,
    topology_classification = classification,
    strongest_prior = strongest$prior_sessions,
    strongest_forward = strongest$forward_sessions,
    strongest_median_pearson = strongest$median_pearson,
    strongest_negative_asset_fraction = strongest$negative_asset_fraction,
    p20_f20_median_pearson = center$median_pearson,
    p20_f20_negative_asset_fraction = center$negative_asset_fraction,
    rebound_weighted_prior_center = if (sum(weights) > 0) sum(x$prior_sessions * weights) / sum(weights) else NA_real_,
    rebound_weighted_forward_center = if (sum(weights) > 0) sum(x$forward_sessions * weights) / sum(weights) else NA_real_,
    p20_prior_row_median = stats::median(p20_row$median_pearson),
    adjacent_prior_rows_median = stats::median(p20_adjacent$median_pearson),
    p20_prior_minus_adjacent = stats::median(p20_row$median_pearson) - stats::median(p20_adjacent$median_pearson),
    f20_forward_column_median = stats::median(f20_column$median_pearson),
    adjacent_forward_columns_median = stats::median(f20_adjacent$median_pearson),
    f20_forward_minus_adjacent = stats::median(f20_column$median_pearson) - stats::median(f20_adjacent$median_pearson),
    stringsAsFactors = FALSE
  )
})
topology_summary <- do.call(rbind, topology_rows)
rownames(topology_summary) <- NULL

cross_sections <- rbind(
  transform(
    cell_summary[cell_summary$prior_sessions == 20L, , drop = FALSE],
    section = "Prior fixed at 20", varying_horizon = forward_sessions
  ),
  transform(
    cell_summary[cell_summary$forward_sessions == 20L, , drop = FALSE],
    section = "Following fixed at 20", varying_horizon = prior_sessions
  )
)

coarse_horizons <- c(10L, 15L, 20L, 25L)
fine_parity <- asset_cells[
  asset_cells$prior_sessions %in% coarse_horizons &
    asset_cells$forward_sessions %in% coarse_horizons,
  c("symbol", "condition", "state", "prior_sessions", "forward_sessions", "pearson_correlation")
]
coarse_parity <- coarse[
  coarse$prior_sessions %in% coarse_horizons &
    coarse$forward_sessions %in% coarse_horizons &
    paste(coarse$condition, coarse$state) %in%
      paste(condition_specs$condition, condition_specs$state),
  c("symbol", "condition", "state", "prior_sessions", "forward_sessions", "negative_pearson_correlation")
]
parity <- merge(
  fine_parity, coarse_parity,
  by = c("symbol", "condition", "state", "prior_sessions", "forward_sessions"),
  all = TRUE, sort = TRUE
)
parity$absolute_difference <- abs(
  parity$pearson_correlation - parity$negative_pearson_correlation
)

expected_asset_rows <- nrow(registry) * length(contract$horizons)^2L * nrow(condition_specs)
checks <- data.frame(
  check = c(
    "registry_exact", "source_bars_sealed", "fine_grid_exact", "asset_rows_exact",
    "three_conditions_exact", "coarse_anchor_parity", "no_inference_columns",
    "minimum_assets_available"
  ),
  status = c(
    if (identical(registry, oarga_expected_registry())) "PASS" else "FAIL",
    if (max(bars$session_date) >= contract$analysis_end &&
        all(vapply(ledgers, function(x) max(x$session_date) <= contract$analysis_end, logical(1)))) "PASS" else "FAIL",
    if (identical(sort(unique(asset_cells$prior_sessions)), contract$horizons) &&
        identical(sort(unique(asset_cells$forward_sessions)), contract$horizons)) "PASS" else "FAIL",
    if (nrow(asset_cells) == expected_asset_rows) "PASS" else "FAIL",
    if (nrow(unique(asset_cells[c("condition", "state")])) == 3L) "PASS" else "FAIL",
    if (nrow(parity) == nrow(fine_parity) && max(parity$absolute_difference, na.rm = TRUE) < 1e-12) "PASS" else "FAIL",
    if (!any(grepl("p_value|q_value|standard_error|lower_95|upper_95", names(asset_cells)))) "PASS" else "FAIL",
    if (all(cell_summary$asset_count >= 20L)) "PASS" else "FAIL"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(parity, file.path(output_dir, "coarse_anchor_parity.csv"), row.names = FALSE, na = "")
utils::write.csv(checks, file.path(output_dir, "topology_checks.csv"), row.names = FALSE, na = "")
if (any(checks$status != "PASS")) {
  stop("One or more rebound-topology checks failed: ",
       paste(checks$check[checks$status != "PASS"], collapse = ", "), call. = FALSE)
}

write_csv <- function(x, filename) utils::write.csv(
  x, file.path(output_dir, filename), row.names = FALSE, na = ""
)
write_csv(asset_cells, "asset_loss_branch_fine_grid.csv")
write_csv(cell_summary, "equal_asset_fine_grid_summary.csv")
write_csv(group_summary, "behavior_group_fine_grid_summary.csv")
write_csv(topology_summary, "topology_summary.csv")
write_csv(cross_sections, "p20_cross_sections.csv")

run_spec <- data.frame(
  field = c(
    "topology_id", "source_packet", "assets", "groups", "analysis_window",
    "returns", "horizons", "primary_surface", "comparators",
    "minimum_negative_branch_observations", "breadth_supported_rule",
    "strong_rebound_rule", "connectivity", "inference", "post_2023",
    "asset_expansion", "trading_calculation"
  ),
  value = c(
    contract$atlas_id,
    "own_asset_return_geometry_atlas_20260826/atlas_query_bars.csv",
    "same frozen 30-asset atlas", "same six groups",
    "2018-01-02 through 2023-12-29", "cumulative close-to-close log return",
    "prior 10:30; following 10:30; one-session increments",
    "negative-prior branch within signed-ER20 DOWN",
    "negative-prior unfiltered; negative-prior ATR% HIGH",
    as.character(contract$minimum_branch_observations),
    ">=20 assets; median Pearson <0; >=60% assets negative",
    ">=20 assets; median Pearson <=-0.10; >=70% assets negative",
    "four-neighbor components on the 21x21 horizon grid",
    "none; descriptive topology only", "none", "none", "none"
  ),
  stringsAsFactors = FALSE
)
write_csv(run_spec, "run_spec.csv")

theme_topology <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", color = "#111827", size = 20),
      plot.subtitle = ggplot2::element_text(color = "#5f6f84", size = 11.5),
      plot.caption = ggplot2::element_text(color = "#64748b", size = 8.5, hjust = 0),
      axis.title = ggplot2::element_text(face = "bold", color = "#34465f", size = 10),
      axis.text = ggplot2::element_text(color = "#26364d", size = 7.5),
      strip.text = ggplot2::element_text(face = "bold", color = "#111827", size = 11),
      panel.grid = ggplot2::element_blank(),
      plot.margin = ggplot2::margin(16, 20, 14, 20)
    )
}

plot_cells <- cell_summary
plot_cells$prior_factor <- factor(plot_cells$prior_sessions, levels = contract$horizons)
plot_cells$forward_factor <- factor(plot_cells$forward_sessions, levels = contract$horizons)
plot_cells$condition_factor <- factor(
  plot_cells$condition_label,
  levels = condition_specs$condition_label
)

p_median <- ggplot2::ggplot(
  plot_cells,
  ggplot2::aes(forward_factor, prior_factor, fill = median_pearson)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.25) +
  ggplot2::geom_tile(
    data = plot_cells[plot_cells$strong_rebound, , drop = FALSE],
    fill = NA, color = "#111827", linewidth = 0.45
  ) +
  ggplot2::facet_wrap(~condition_factor, nrow = 1) +
  ggplot2::scale_fill_gradient2(
    low = "#c94f4f", mid = "#f7f7f7", high = "#4b91cf",
    midpoint = 0, limits = c(-0.30, 0.10), oob = scales::squish,
    name = "Median r"
  ) +
  ggplot2::labs(
    title = "Fine resolution reveals the rebound topology",
    subtitle = "Black outlines mark strong cells: median r <= -0.10 and at least 70% of assets negative.",
    x = "Following sessions", y = "Prior sessions",
    caption = "Equal-asset medians across the frozen 30-asset atlas. Adjacent cells are highly dependent; this is morphology, not 441 independent tests."
  ) +
  theme_topology(11) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5))
ggplot2::ggsave(
  file.path(visual_dir, "fine_grid_equal_asset_median_surfaces.png"),
  p_median, width = 12.8, height = 7.2, dpi = 220, bg = "white"
)

p_breadth <- ggplot2::ggplot(
  plot_cells,
  ggplot2::aes(forward_factor, prior_factor, fill = negative_asset_fraction)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.25) +
  ggplot2::geom_tile(
    data = plot_cells[plot_cells$strong_rebound, , drop = FALSE],
    fill = NA, color = "#111827", linewidth = 0.45
  ) +
  ggplot2::facet_wrap(~condition_factor, nrow = 1) +
  ggplot2::scale_fill_gradient(
    low = "#f4f6f8", high = "#b9242f", limits = c(0.40, 1.00),
    oob = scales::squish, name = "Assets\nnegative"
  ) +
  ggplot2::labs(
    title = "Cross-asset breadth distinguishes local color from shared shape",
    subtitle = "Darker cells mean a larger fraction of assets show within-loss rebound geometry.",
    x = "Following sessions", y = "Prior sessions",
    caption = "Each cell uses all estimable atlas assets. Black outlines use the same strong-cell rule as the median surface."
  ) +
  theme_topology(11) +
  ggplot2::theme(axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5))
ggplot2::ggsave(
  file.path(visual_dir, "fine_grid_cross_asset_breadth_surfaces.png"),
  p_breadth, width = 12.8, height = 7.2, dpi = 220, bg = "white"
)

condition_colors <- c(
  "UNFILTERED LOSS" = "#6D7A86",
  "ATR% HIGH LOSS" = "#D9822B",
  "SIGNED DOWN LOSS" = "#C64B4B"
)
cross_sections$condition_factor <- factor(
  cross_sections$condition_label,
  levels = condition_specs$condition_label
)
cross_sections$section <- factor(
  cross_sections$section,
  levels = c("Prior fixed at 20", "Following fixed at 20")
)
p_cross <- ggplot2::ggplot(
  cross_sections,
  ggplot2::aes(varying_horizon, median_pearson, color = condition_factor)
) +
  ggplot2::geom_hline(yintercept = 0, color = "#b8c0ca", linewidth = 0.6) +
  ggplot2::geom_vline(xintercept = 20, color = "#111827", linetype = "dashed", linewidth = 0.6) +
  ggplot2::geom_line(linewidth = 1.2) +
  ggplot2::geom_point(size = 2.0) +
  ggplot2::facet_wrap(~section, nrow = 1) +
  ggplot2::scale_color_manual(values = condition_colors, name = NULL) +
  ggplot2::scale_x_continuous(breaks = seq(10, 30, 2)) +
  ggplot2::labs(
    title = "Cross-sections test whether the surface is pinned to 20 sessions",
    subtitle = "A singular window-20 artifact would appear as a sharp local notch rather than a broad curve.",
    x = "Varying horizon", y = "Equal-asset median Pearson r",
    caption = "Dashed line marks 20 sessions. The two panels hold the other horizon fixed at 20."
  ) +
  theme_topology(12) +
  ggplot2::theme(legend.position = "bottom")
ggplot2::ggsave(
  file.path(visual_dir, "p20_topology_cross_sections.png"),
  p_cross, width = 12.8, height = 7.2, dpi = 220, bg = "white"
)

group_plot <- group_summary[
  group_summary$condition == "SIGNED_ER20" & group_summary$state == "DOWN_TREND",
  , drop = FALSE
]
group_plot$prior_factor <- factor(group_plot$prior_sessions, levels = contract$horizons)
group_plot$forward_factor <- factor(group_plot$forward_sessions, levels = contract$horizons)
p_groups <- ggplot2::ggplot(
  group_plot,
  ggplot2::aes(forward_factor, prior_factor, fill = median_pearson)
) +
  ggplot2::geom_tile(color = "white", linewidth = 0.18) +
  ggplot2::facet_wrap(~behavior_group, nrow = 2) +
  ggplot2::scale_fill_gradient2(
    low = "#c94f4f", mid = "#f7f7f7", high = "#4b91cf",
    midpoint = 0, limits = c(-0.45, 0.15), oob = scales::squish,
    name = "Group\nmedian r"
  ) +
  ggplot2::labs(
    title = "All six behavior groups can be inspected without pooling their identities",
    subtitle = "The signed-DOWN loss branch is mapped separately within each frozen five-asset group.",
    x = "Following sessions", y = "Prior sessions",
    caption = "Five assets per group remain exploratory representation, not an asset-class population estimate."
  ) +
  theme_topology(10) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(angle = 90, vjust = 0.5, size = 5.8),
    axis.text.y = ggplot2::element_text(size = 5.8),
    strip.text = ggplot2::element_text(size = 9.5)
  )
ggplot2::ggsave(
  file.path(visual_dir, "signed_down_behavior_group_surfaces.png"),
  p_groups, width = 12.8, height = 7.2, dpi = 220, bg = "white"
)

topology_long <- rbind(
  data.frame(
    condition_label = topology_summary$condition_label,
    metric = "Breadth-supported", share = topology_summary$breadth_supported_fraction,
    stringsAsFactors = FALSE
  ),
  data.frame(
    condition_label = topology_summary$condition_label,
    metric = "Strong", share = topology_summary$strong_rebound_fraction,
    stringsAsFactors = FALSE
  )
)
topology_long$condition_label <- factor(
  topology_long$condition_label,
  levels = rev(condition_specs$condition_label)
)
p_summary <- ggplot2::ggplot(
  topology_long,
  ggplot2::aes(share, condition_label, fill = metric)
) +
  ggplot2::geom_col(position = "dodge", width = 0.66) +
  ggplot2::geom_text(
    ggplot2::aes(label = sprintf("%.0f%%", 100 * share)),
    position = ggplot2::position_dodge(width = 0.66),
    hjust = -0.12, size = 4.1, color = "#26364d"
  ) +
  ggplot2::scale_fill_manual(
    values = c("Breadth-supported" = "#75A6D1", "Strong" = "#C64B4B"),
    name = NULL
  ) +
  ggplot2::scale_x_continuous(
    limits = c(0, 1.02), breaks = seq(0, 1, 0.2),
    labels = function(x) paste0(round(100 * x), "%")
  ) +
  ggplot2::labs(
    title = "Topology is summarized by coverage, not the hottest cell",
    subtitle = "Breadth-supported and strong cells use predeclared cross-asset rules across all 441 horizon pairs.",
    x = "Share of eligible cells", y = NULL,
    caption = "Connected-component boundaries and window-20 ridge diagnostics are reported in topology_summary.csv."
  ) +
  theme_topology(13) +
  ggplot2::theme(legend.position = "bottom", axis.text.y = ggplot2::element_text(face = "bold", size = 11))
ggplot2::ggsave(
  file.path(visual_dir, "topology_coverage_summary.png"),
  p_summary, width = 12.8, height = 7.2, dpi = 220, bg = "white"
)

summary_line <- function(row) {
  sprintf(
    "- %s: %d/%d breadth-supported cells, %d/%d strong cells; largest strong component %d cells; %s; strongest %d->%d at r=%+.4f; p20/f20 r=%+.4f.",
    row$condition_label, row$breadth_supported_cells, row$eligible_cells,
    row$strong_rebound_cells, row$eligible_cells,
    row$largest_strong_component_cells, row$topology_classification,
    row$strongest_prior, row$strongest_forward,
    row$strongest_median_pearson, row$p20_f20_median_pearson
  )
}
report_lines <- c(
  "# Own-Asset Loss-Rebound Topology: 2018-2023",
  "",
  "Status: `DESCRIPTIVE_FINE_GRID_COMPLETE_NO_INFERENCE_OR_EDGE_CLAIM`",
  "",
  "## Frozen Question",
  "",
  "Does the transported loss-rebound neighborhood form a broad plateau, a bounded island, or a narrow feature pinned to the 20-session signed-ER window?",
  "",
  "## Contract",
  "",
  "- Same frozen 30 assets, six groups, adjusted daily bars, and 2018-2023 analysis window.",
  "- Prior and following horizons are 10 through 30 sessions in one-session increments.",
  "- Primary surface: negative-prior branch within signed-ER20 DOWN.",
  "- Controls: negative-prior unfiltered and negative-prior ATR% HIGH.",
  "- No cellwise p-values, BH scan, later-period data, asset expansion, or trading calculation.",
  "",
  "## Descriptive Readout",
  "",
  vapply(seq_len(nrow(topology_summary)), function(i) summary_line(topology_summary[i, ]), character(1L)),
  "",
  "## Interpretation Boundary",
  "",
  "Adjacent horizons share most of their observations, so smooth surfaces are expected even under sampling noise. The topology pass earns a shape description, not hundreds of independent confirmations. A connected component that touches the 10-30 boundary is open within the inspected window and should not be called a bounded island.",
  "",
  "The p=20 and f=20 cross-sections compare the exact signed-ER window with neighboring horizons. A sharp isolated notch would increase concern about measurement coupling; a broad curve would be more consistent with multiscale morphology. Neither pattern establishes a causal mechanism or realizable expectancy."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Rebound topology complete: ", normalizePath(output_dir, winslash = "/"))
message("Rows: ", nrow(asset_cells), "; cells: ", nrow(cell_summary),
        "; checks: ", paste(checks$status, collapse = ","))
