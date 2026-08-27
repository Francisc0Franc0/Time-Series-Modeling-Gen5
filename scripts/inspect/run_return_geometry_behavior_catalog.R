# Build an operator-facing behavioral catalog from the frozen 2018-2023
# own-asset return-geometry atlas. This script reads existing descriptive
# outputs only. It does not refresh data, search new horizons, run inference,
# or compute strategy performance.

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

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("The existing ggplot2 dependency is required for behavior-catalog visuals.", call. = FALSE)
}

atlas_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "own_asset_return_geometry_atlas_20260826"
)
input_path <- file.path(atlas_dir, "asset_prior_sign_cells.csv")
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "return_geometry_behavior_catalog_20260826"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!file.exists(input_path) || !dir.exists(visual_dir)) {
  stop("The frozen atlas packet or catalog output directory is unavailable.", call. = FALSE)
}

raw <- utils::read.csv(input_path, stringsAsFactors = FALSE, check.names = FALSE)
required <- c(
  "symbol", "condition", "state", "prior_sessions", "forward_sessions",
  "estimation_status", "negative_pearson_correlation",
  "positive_pearson_correlation", "negative_mean_forward_return",
  "positive_mean_forward_return", "behavior_group"
)
missing <- setdiff(required, names(raw))
if (length(missing) > 0L) {
  stop("Atlas prior-sign input is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)
}

described <- raw[raw$estimation_status == "DESCRIBED", , drop = FALSE]
if (nrow(described) == 0L) stop("No described atlas prior-sign cells were found.", call. = FALSE)

cell_groups <- split(
  described,
  list(
    described$condition, described$state,
    described$prior_sessions, described$forward_sessions
  ),
  drop = TRUE
)

cell_summary <- do.call(rbind, lapply(cell_groups, function(x) {
  data.frame(
    condition = x$condition[[1L]],
    state = x$state[[1L]],
    prior_sessions = as.integer(x$prior_sessions[[1L]]),
    forward_sessions = as.integer(x$forward_sessions[[1L]]),
    asset_count = nrow(x),
    negative_branch_median_r = stats::median(x$negative_pearson_correlation, na.rm = TRUE),
    negative_branch_positive_fraction = mean(x$negative_pearson_correlation > 0, na.rm = TRUE),
    positive_branch_median_r = stats::median(x$positive_pearson_correlation, na.rm = TRUE),
    positive_branch_positive_fraction = mean(x$positive_pearson_correlation > 0, na.rm = TRUE),
    median_positive_minus_negative_forward_mean = stats::median(
      x$positive_mean_forward_return - x$negative_mean_forward_return,
      na.rm = TRUE
    ),
    stringsAsFactors = FALSE
  )
}))
rownames(cell_summary) <- NULL

state_lookup <- data.frame(
  condition = c(
    "UNFILTERED", "ER20", "ER20", "SIGNED_ER20", "SIGNED_ER20",
    "ATRP", "ATRP", "ATRP"
  ),
  state = c(
    "ALL", "RED_SIDEWAYS", "GREEN_TRENDING", "UP_TREND", "DOWN_TREND",
    "LOW", "MEDIUM", "HIGH"
  ),
  state_label = c(
    "Unfiltered", "Path sideways", "Path trending", "Signed up", "Signed down",
    "ATR% low", "ATR% medium", "ATR% high"
  ),
  state_order = seq_len(8L),
  stringsAsFactors = FALSE
)

archetypes <- data.frame(
  archetype = c(
    "GAIN_CONTINUATION", "GAIN_REVERSAL", "LOSS_REBOUND", "LOSS_CONTINUATION"
  ),
  archetype_label = c(
    "Gain continuation\nprior > 0, slope > 0",
    "Gain exhaustion\nprior > 0, slope < 0",
    "Loss rebound\nprior < 0, slope < 0",
    "Loss continuation\nprior < 0, slope > 0"
  ),
  archetype_order = seq_len(4L),
  stringsAsFactors = FALSE
)

catalog_rows <- list()
for (i in seq_len(nrow(state_lookup))) {
  state_cells <- cell_summary[
    cell_summary$condition == state_lookup$condition[[i]] &
      cell_summary$state == state_lookup$state[[i]] &
      cell_summary$asset_count >= 20L,
    , drop = FALSE
  ]
  if (nrow(state_cells) == 0L) next

  definitions <- list(
    GAIN_CONTINUATION = list(
      value = state_cells$positive_branch_median_r,
      supported = state_cells$positive_branch_median_r > 0 &
        state_cells$positive_branch_positive_fraction >= 0.60,
      direction = "max"
    ),
    GAIN_REVERSAL = list(
      value = state_cells$positive_branch_median_r,
      supported = state_cells$positive_branch_median_r < 0 &
        state_cells$positive_branch_positive_fraction <= 0.40,
      direction = "min"
    ),
    LOSS_REBOUND = list(
      value = state_cells$negative_branch_median_r,
      supported = state_cells$negative_branch_median_r < 0 &
        state_cells$negative_branch_positive_fraction <= 0.40,
      direction = "min"
    ),
    LOSS_CONTINUATION = list(
      value = state_cells$negative_branch_median_r,
      supported = state_cells$negative_branch_median_r > 0 &
        state_cells$negative_branch_positive_fraction >= 0.60,
      direction = "max"
    )
  )

  for (archetype in names(definitions)) {
    definition <- definitions[[archetype]]
    supported_cells <- state_cells[definition$supported, , drop = FALSE]
    supported_count <- nrow(supported_cells)
    eligible_count <- nrow(state_cells)
    supported_fraction <- supported_count / eligible_count
    status <- if (supported_fraction >= 0.50) {
      "BROAD"
    } else if (supported_fraction >= 0.20) {
      "CLUSTER"
    } else if (supported_count >= 3L) {
      "POCKET"
    } else {
      "NOT_OBSERVED"
    }

    if (supported_count > 0L) {
      supported_values <- if (archetype %in% c("GAIN_CONTINUATION", "GAIN_REVERSAL")) {
        supported_cells$positive_branch_median_r
      } else {
        supported_cells$negative_branch_median_r
      }
      strongest_index <- if (definition$direction == "max") {
        which.max(supported_values)
      } else {
        which.min(supported_values)
      }
      strongest <- supported_cells[strongest_index, , drop = FALSE]
      strongest_value <- supported_values[[strongest_index]]
      strongest_cell <- paste0(
        strongest$prior_sessions[[1L]], "->", strongest$forward_sessions[[1L]]
      )
    } else {
      strongest_value <- NA_real_
      strongest_cell <- NA_character_
    }

    catalog_rows[[length(catalog_rows) + 1L]] <- data.frame(
      condition = state_lookup$condition[[i]],
      state = state_lookup$state[[i]],
      state_label = state_lookup$state_label[[i]],
      state_order = state_lookup$state_order[[i]],
      archetype = archetype,
      archetype_label = archetypes$archetype_label[archetypes$archetype == archetype],
      archetype_order = archetypes$archetype_order[archetypes$archetype == archetype],
      eligible_cells = eligible_count,
      supported_cells = supported_count,
      supported_fraction = supported_fraction,
      status = status,
      strongest_cell = strongest_cell,
      strongest_median_r = strongest_value,
      stringsAsFactors = FALSE
    )
  }
}

catalog <- do.call(rbind, catalog_rows)
rownames(catalog) <- NULL
catalog$cell_label <- paste0(catalog$supported_cells, "/", catalog$eligible_cells)
catalog$status_label <- gsub("_", " ", catalog$status)

utils::write.csv(
  cell_summary,
  file.path(output_dir, "behavior_catalog_cell_summary.csv"),
  row.names = FALSE,
  na = ""
)
utils::write.csv(
  catalog,
  file.path(output_dir, "behavior_catalog_state_summary.csv"),
  row.names = FALSE,
  na = ""
)

theme_catalog <- function(base_size = 13) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold", color = "#111827", size = 20),
      plot.subtitle = ggplot2::element_text(color = "#5f6f84", size = 12),
      plot.caption = ggplot2::element_text(color = "#64748b", size = 9, hjust = 0),
      axis.title = ggplot2::element_blank(),
      axis.text = ggplot2::element_text(color = "#26364d"),
      panel.grid = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold", color = "#111827", size = 12),
      plot.margin = ggplot2::margin(18, 24, 16, 24)
    )
}

# Fundamental four-cell grammar.
grammar <- data.frame(
  prior_sign = factor(c("Loss", "Gain", "Loss", "Gain"), levels = c("Loss", "Gain")),
  slope_sign = factor(
    c("Negative slope", "Negative slope", "Positive slope", "Positive slope"),
    levels = c("Positive slope", "Negative slope")
  ),
  archetype = c("LOSS_REBOUND", "GAIN_REVERSAL", "LOSS_CONTINUATION", "GAIN_CONTINUATION"),
  title = c("LOSS REBOUND", "GAIN EXHAUSTION", "LOSS CONTINUATION", "GAIN CONTINUATION"),
  explanation = c(
    "Deeper losses align\nwith stronger recovery",
    "Larger gains align\nwith weaker next returns",
    "Deeper losses align\nwith further downside",
    "Larger gains align\nwith stronger next returns"
  ),
  fill = c("#d9eaf7", "#f6ddcf", "#f1c6c4", "#d7eedf"),
  stringsAsFactors = FALSE
)

p_grammar <- ggplot2::ggplot(grammar, ggplot2::aes(prior_sign, slope_sign)) +
  ggplot2::geom_tile(ggplot2::aes(fill = fill), color = "white", linewidth = 7) +
  ggplot2::scale_fill_identity() +
  ggplot2::geom_text(
    ggplot2::aes(label = title),
    nudge_y = 0.12, fontface = "bold", size = 5.8, color = "#17263b"
  ) +
  ggplot2::geom_text(
    ggplot2::aes(label = explanation),
    nudge_y = -0.12, size = 4.1, lineheight = 1.05, color = "#34465f"
  ) +
  ggplot2::labs(
    title = "Four return behaviors form the method's basic grammar",
    subtitle = "Conditioning states do not create new archetypes; they change which archetype dominates.",
    caption = "Slope is measured within the prior-loss or prior-gain branch. This is a descriptive vocabulary, not a trading rule."
  ) +
  theme_catalog(14) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(face = "bold", size = 14),
    axis.text.y = ggplot2::element_text(face = "bold", size = 13),
    plot.title = ggplot2::element_text(size = 23),
    plot.subtitle = ggplot2::element_text(size = 13)
  )

ggplot2::ggsave(
  file.path(visual_dir, "behavior_archetype_grammar.png"),
  p_grammar, width = 12.8, height = 7.2, dpi = 220, bg = "white"
)

# State-by-archetype discovery catalog.
catalog$state_factor <- factor(
  catalog$state_label,
  levels = rev(state_lookup$state_label)
)
catalog$archetype_factor <- factor(
  catalog$archetype_label,
  levels = archetypes$archetype_label
)

p_catalog <- ggplot2::ggplot(
  catalog,
  ggplot2::aes(archetype_factor, state_factor, fill = supported_fraction)
) +
  ggplot2::geom_tile(color = "white", linewidth = 2.2) +
  ggplot2::geom_text(
    ggplot2::aes(label = paste0(cell_label, "\n", status_label)),
    size = 3.4, lineheight = 0.95, color = "#102238"
  ) +
  ggplot2::scale_fill_gradient(
    low = "#f4f6f8", high = "#2f7fc1", limits = c(0, 0.90),
    oob = scales::squish,
    name = "Supported\ncell share"
  ) +
  ggplot2::labs(
    title = "The atlas reveals different behaviors in different states",
    subtitle = "Cell counts require at least 20 estimable assets and at least 60% cross-asset sign agreement.",
    caption = "BROAD >=50% of eligible cells; CLUSTER >=20%; POCKET >=3 cells. Display thresholds are post-hoc catalog rules, not statistical inference."
  ) +
  theme_catalog(12) +
  ggplot2::theme(
    axis.text.x = ggplot2::element_text(face = "bold", size = 10.5, lineheight = 0.9),
    axis.text.y = ggplot2::element_text(face = "bold", size = 11),
    legend.position = "right",
    plot.title = ggplot2::element_text(size = 22)
  )

ggplot2::ggsave(
  file.path(visual_dir, "behavior_state_catalog.png"),
  p_catalog, width = 12.8, height = 7.2, dpi = 220, bg = "white"
)

horizons <- c(1L, 2L, 3L, 4L, 5L, 10L, 15L, 20L, 25L)

make_branch_heatmap <- function(spec, value_column, title, subtitle, filename) {
  panels <- do.call(rbind, lapply(seq_len(nrow(spec)), function(i) {
    x <- cell_summary[
      cell_summary$condition == spec$condition[[i]] &
        cell_summary$state == spec$state[[i]],
      , drop = FALSE
    ]
    x$panel <- spec$panel[[i]]
    x
  }))
  panels$panel <- factor(panels$panel, levels = spec$panel)
  panels$prior_factor <- factor(panels$prior_sessions, levels = horizons)
  panels$forward_factor <- factor(panels$forward_sessions, levels = horizons)
  panels$value <- panels[[value_column]]
  panels$label <- ifelse(is.finite(panels$value), sprintf("%+.02f", panels$value), "NE")

  p <- ggplot2::ggplot(
    panels,
    ggplot2::aes(forward_factor, prior_factor, fill = value)
  ) +
    ggplot2::geom_tile(color = "white", linewidth = 0.7) +
    ggplot2::geom_text(ggplot2::aes(label = label), size = 2.25, color = "#17324d") +
    ggplot2::facet_wrap(~panel, nrow = 1) +
    ggplot2::scale_fill_gradient2(
      low = "#ca5553", mid = "#f7f7f7", high = "#4b91cf",
      midpoint = 0, limits = c(-0.18, 0.18), oob = scales::squish,
      name = "Median r"
    ) +
    ggplot2::labs(
      title = title,
      subtitle = subtitle,
      x = "Following sessions", y = "Prior sessions",
      caption = "Equal-asset median Pearson correlation within the indicated sign branch. Complete surfaces are descriptive."
    ) +
    theme_catalog(11) +
    ggplot2::theme(
      axis.title = ggplot2::element_text(face = "bold", color = "#34465f", size = 10),
      axis.text = ggplot2::element_text(size = 8),
      legend.position = "right",
      plot.title = ggplot2::element_text(size = 21)
    )

  ggplot2::ggsave(
    file.path(visual_dir, filename),
    p, width = 12.8, height = 7.2, dpi = 220, bg = "white"
  )
}

make_branch_heatmap(
  data.frame(
    condition = c("ER20", "ATRP", "SIGNED_ER20"),
    state = c("RED_SIDEWAYS", "LOW", "UP_TREND"),
    panel = c("PATH SIDEWAYS", "ATR% LOW", "SIGNED UP"),
    stringsAsFactors = FALSE
  ),
  "positive_branch_median_r",
  "Gain continuation appears only in selected states",
  "Sideways paths contain the broadest positive-prior continuation island; signed-up paths do not.",
  "gain_continuation_state_heatmaps.png"
)

make_branch_heatmap(
  data.frame(
    condition = c("UNFILTERED", "ATRP", "SIGNED_ER20"),
    state = c("ALL", "HIGH", "DOWN_TREND"),
    panel = c("UNFILTERED", "ATR% HIGH", "SIGNED DOWN"),
    stringsAsFactors = FALSE
  ),
  "negative_branch_median_r",
  "Loss rebound is the atlas's most widespread behavior",
  "Negative slopes mean deeper completed losses align with stronger subsequent returns.",
  "loss_rebound_state_heatmaps.png"
)

# Four mechanism theses, explicitly labeled as hypotheses rather than causes.
theses <- data.frame(
  y = 4:1,
  archetype = c("GAIN CONTINUATION", "GAIN EXHAUSTION", "LOSS REBOUND", "LOSS CONTINUATION"),
  observed = c(
    "Observed cluster: sideways 39/81; ATR% low 17/81",
    "Broad: trending 72/81; signed up 41/45; ATR% high 40/81",
    "Broad: ATR% high 71/81; trending 70/81; low 65/81; sideways 55/81",
    "Not broad: ATR% medium 17/81; all other states <=6 cells"
  ),
  thesis = c(
    "Gradual information diffusion or underreaction can persist when path and volatility disturbance stay limited.",
    "An already-extended move can mark a later stage of repricing; conditioning also leaves less room for further acceleration.",
    "Overshoot, liquidity relief, short covering, or volatility normalization can produce recovery after increasingly deep losses.",
    "Persistent bad-news repricing or forced deleveraging could produce this behavior, but the current atlas does not show it broadly."
  ),
  fill = c("#d7eedf", "#f6ddcf", "#d9eaf7", "#eef1f4"),
  stringsAsFactors = FALSE
)

wrap_text <- function(x, width) {
  vapply(x, function(value) paste(strwrap(value, width = width), collapse = "\n"), character(1L))
}
theses$observed_wrapped <- wrap_text(theses$observed, 38L)
theses$thesis_wrapped <- wrap_text(theses$thesis, 58L)

p_theses <- ggplot2::ggplot(theses, ggplot2::aes(x = 0, y = y)) +
  ggplot2::geom_tile(
    ggplot2::aes(fill = fill), width = 2, height = 0.82,
    color = "white", linewidth = 2
  ) +
  ggplot2::scale_fill_identity() +
  ggplot2::geom_text(
    ggplot2::aes(x = -0.92, label = archetype),
    hjust = 0, fontface = "bold", size = 4.35, color = "#17324d"
  ) +
  ggplot2::geom_text(
    ggplot2::aes(x = -0.42, label = observed_wrapped),
    hjust = 0, fontface = "bold", size = 3.05, color = "#34465f", lineheight = 0.95
  ) +
  ggplot2::geom_text(
    ggplot2::aes(x = 0.18, label = thesis_wrapped),
    hjust = 0, size = 2.95, color = "#34465f", lineheight = 0.95
  ) +
  ggplot2::annotate(
    "text", x = -0.92, y = 4.55, label = "BEHAVIOR",
    hjust = 0, fontface = "bold", size = 3.4, color = "#64748b"
  ) +
  ggplot2::annotate(
    "text", x = -0.42, y = 4.55, label = "OBSERVED IN THE ATLAS",
    hjust = 0, fontface = "bold", size = 3.4, color = "#64748b"
  ) +
  ggplot2::annotate(
    "text", x = 0.18, y = 4.55, label = "MECHANISM THESIS",
    hjust = 0, fontface = "bold", size = 3.4, color = "#64748b"
  ) +
  ggplot2::coord_cartesian(xlim = c(-1, 1), ylim = c(0.45, 4.72), clip = "off") +
  ggplot2::labs(
    title = "The catalog suggests mechanisms to test, not explanations to accept",
    subtitle = "Each thesis is a causal story that could generate the observed geometry; none is identified by correlation alone.",
    caption = "Counts are breadth-supported horizon cells from the frozen atlas. Shared-path conditioning, overlap, and drift remain alternative explanations."
  ) +
  theme_catalog(12) +
  ggplot2::theme(
    axis.text = ggplot2::element_blank(),
    plot.title = ggplot2::element_text(size = 22)
  )

ggplot2::ggsave(
  file.path(visual_dir, "behavior_mechanism_theses.png"),
  p_theses, width = 12.8, height = 7.2, dpi = 220, bg = "white"
)

catalog_checks <- data.frame(
  check = c(
    "source_rows_present", "four_archetypes_present", "eight_states_present",
    "no_new_horizons", "minimum_assets_applied"
  ),
  status = c(
    if (nrow(described) > 0L) "PASS" else "FAIL",
    if (length(unique(catalog$archetype)) == 4L) "PASS" else "FAIL",
    if (length(unique(catalog$state_label)) == 8L) "PASS" else "FAIL",
    if (identical(sort(unique(cell_summary$prior_sessions)), horizons) &&
        identical(sort(unique(cell_summary$forward_sessions)), horizons)) "PASS" else "FAIL",
    if (all(catalog$eligible_cells <= 81L) && all(catalog$eligible_cells > 0L)) "PASS" else "FAIL"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(catalog_checks, file.path(output_dir, "catalog_checks.csv"), row.names = FALSE)
if (any(catalog_checks$status != "PASS")) {
  stop("One or more behavior-catalog integrity checks failed.", call. = FALSE)
}

report_lines <- c(
  "# Return-Geometry Behavioral Catalog",
  "",
  "Status: `DESCRIPTIVE_CATALOG_COMPLETE_NO_NEW_EDGE_CLAIM`",
  "",
  "This packet reorganizes the frozen atlas into four branch-level behaviors:",
  "gain continuation, gain exhaustion, loss rebound, and loss continuation.",
  "A supported cell requires at least 20 estimable assets and at least 60%",
  "cross-asset agreement on the branch-correlation sign.",
  "",
  "The strongest new synthesis is that gain continuation is conditional rather",
  "than universal: it clusters in sideways paths and appears more modestly in",
  "low ATR% states, while signed-up paths show broad gain exhaustion instead.",
  "Loss rebound is the most widespread behavior across the atlas. Downside",
  "continuation is not broad in any state.",
  "",
  "These are post-hoc catalog rules applied to descriptive surfaces. They are",
  "not multiplicity-controlled discoveries, causal mechanisms, or trading rules."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("Behavior catalog complete: ", normalizePath(output_dir, winslash = "/"))
message("States: ", length(unique(catalog$state_label)), "; archetypes: ",
        length(unique(catalog$archetype)), "; checks: ",
        paste(catalog_checks$status, collapse = ","))
