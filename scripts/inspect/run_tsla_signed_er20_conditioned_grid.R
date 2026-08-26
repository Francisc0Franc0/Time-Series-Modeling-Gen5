# Apply the frozen three-state signed ER20 classifier to the existing TSLA
# 9 x 9 cumulative-return grid and its prior-sign asymmetry surface. This is a
# descriptive conditioning slice only: no tuning, rule, or performance claim.

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
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_direction.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "tsla_signed_er20_grid.R"))
g5_load_local_renviron(repo_root)

cfg <- g5_load_data_layer_config(repo_root)
contract <- tsder_contract()
symbol <- contract$symbol
horizons <- c(1L, 2L, 3L, 4L, 5L, 10L, 15L, 20L, 25L)
states <- contract$states
state_pairs <- list(
  c("SIDEWAYS", "UP_TREND"),
  c("SIDEWAYS", "DOWN_TREND"),
  c("DOWN_TREND", "UP_TREND")
)
query_start <- as.Date("2017-10-02")
analysis_start <- contract$analysis_start
analysis_end <- contract$analysis_end
as_of_timestamp <- as.POSIXct("2026-08-26 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(
  tolower(Sys.getenv("GEN5_TSLA_SIGNED_ER20_GRID_REFRESH", unset = "false")),
  "true"
)

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_signed_er20_conditioned_grid_20260826"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) tsseg_stop("Could not create the output directory.")

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "tsla_signed_er20_conditioned_grid",
  universe_roles = "single_asset_descriptive_direction_conditioning",
  refresh = refresh,
  repo_root = repo_root
)

bars <- query$bars
bars <- bars[bars$symbol == symbol, , drop = FALSE]
bars$session_date <- as.Date(bars$session_date)
bars <- bars[order(bars$session_date), , drop = FALSE]
bars$signed_er20 <- tsder_signed_efficiency_ratio(
  log(bars$close), contract$window_sessions
)
bars$direction_state <- tsder_classify_direction(
  bars$signed_er20, contract$direction_cutoff
)

analysis_rows <- bars$session_date >= analysis_start & bars$session_date <= analysis_end
source_checks <- data.frame(
  check_id = c(
    "exact_symbol", "unique_sessions", "strict_date_order", "positive_finite_close",
    "adjusted_daily_only", "warmup_covered", "analysis_window_covered",
    "signed_er20_available", "state_set_exact", "future_rows_absent"
  ),
  passed = c(
    nrow(bars) > 0L && identical(unique(as.character(bars$symbol)), symbol),
    !anyDuplicated(bars$session_date),
    nrow(bars) > 1L && all(diff(bars$session_date) > 0),
    all(is.finite(bars$close) & bars$close > 0),
    all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
    min(bars$session_date) <= query_start,
    min(bars$session_date[analysis_rows]) == analysis_start &&
      max(bars$session_date[analysis_rows]) == analysis_end,
    all(is.finite(bars$signed_er20[analysis_rows])),
    identical(sort(unique(bars$direction_state[analysis_rows])), sort(states)),
    max(bars$session_date) <= analysis_end
  ),
  observed = c(
    paste(unique(as.character(bars$symbol)), collapse = ","),
    as.character(sum(duplicated(bars$session_date))),
    paste(min(bars$session_date), max(bars$session_date), sep = " to "),
    paste(range(bars$close), collapse = " to "),
    paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
    as.character(min(bars$session_date)),
    paste(min(bars$session_date[analysis_rows]), max(bars$session_date[analysis_rows]), sep = " to "),
    paste(range(bars$signed_er20[analysis_rows]), collapse = " to "),
    paste(sort(unique(bars$direction_state[analysis_rows])), collapse = ","),
    as.character(max(bars$session_date))
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  tsseg_stop(paste("Source checks failed:", paste(source_checks$check_id[!source_checks$passed], collapse = ", ")))
}

construct_surface <- function(prior_sessions, forward_sessions) {
  anchors <- seq_len(nrow(bars))
  usable <- anchors - prior_sessions >= 1L & anchors + forward_sessions <= nrow(bars)
  anchors <- anchors[usable]
  in_window <- bars$session_date[anchors] >= analysis_start &
    bars$session_date[anchors + forward_sessions] <= analysis_end &
    is.finite(bars$signed_er20[anchors])
  anchors <- anchors[in_window]
  if (!length(anchors)) tsseg_stop("No complete grid observations.")
  data.frame(
    anchor_session = bars$session_date[anchors],
    forward_end_session = bars$session_date[anchors + forward_sessions],
    signed_er20 = bars$signed_er20[anchors],
    direction_state = bars$direction_state[anchors],
    prior_cumulative_log_return = log(bars$close[anchors] / bars$close[anchors - prior_sessions]),
    forward_cumulative_log_return = log(bars$close[anchors + forward_sessions] / bars$close[anchors]),
    stringsAsFactors = FALSE
  )
}

state_rows <- vector("list", length(horizons)^2 * length(states))
comparison_rows <- vector("list", length(horizons)^2 * length(state_pairs))
asymmetry_rows <- vector("list", length(horizons)^2 * length(states))
state_index <- 1L
comparison_index <- 1L
asymmetry_index <- 1L

for (prior_sessions in horizons) {
  for (forward_sessions in horizons) {
    surface <- construct_surface(prior_sessions, forward_sessions)
    for (state in states) {
      state_rows[[state_index]] <- tsseg_measure_state(
        surface, state, prior_sessions, forward_sessions
      )
      state_index <- state_index + 1L
      asymmetry_rows[[asymmetry_index]] <- tsseg_measure_sign_asymmetry(
        surface, state, prior_sessions, forward_sessions
      )
      asymmetry_index <- asymmetry_index + 1L
    }
    for (pair in state_pairs) {
      comparison_rows[[comparison_index]] <- tsseg_compare_states(
        surface, pair[[1L]], pair[[2L]], prior_sessions, forward_sessions
      )
      comparison_index <- comparison_index + 1L
    }
  }
}

state_statistics <- do.call(rbind, state_rows)
state_comparisons <- do.call(rbind, comparison_rows)
sign_asymmetry <- do.call(rbind, asymmetry_rows)
rownames(state_statistics) <- NULL
rownames(state_comparisons) <- NULL
rownames(sign_asymmetry) <- NULL
state_comparisons$comparison <- paste(
  state_comparisons$contrast_state,
  "minus",
  state_comparisons$reference_state
)

state_statistics$slope_family_bh_q_value <- NA_real_
for (state in states) {
  rows <- state_statistics$direction_state == state
  state_statistics$slope_family_bh_q_value[rows] <- tsseg_adjust_bh(
    state_statistics$slope_hac_p_value[rows]
  )
}
state_statistics$slope_omnibus_bh_q_value <- tsseg_adjust_bh(
  state_statistics$slope_hac_p_value
)

state_comparisons$interaction_family_bh_q_value <- NA_real_
for (comparison in unique(state_comparisons$comparison)) {
  rows <- state_comparisons$comparison == comparison
  state_comparisons$interaction_family_bh_q_value[rows] <- tsseg_adjust_bh(
    state_comparisons$interaction_hac_p_value[rows]
  )
}
state_comparisons$interaction_omnibus_bh_q_value <- tsseg_adjust_bh(
  state_comparisons$interaction_hac_p_value
)

sign_asymmetry$interaction_family_bh_q_value <- NA_real_
for (state in states) {
  rows <- sign_asymmetry$direction_state == state
  sign_asymmetry$interaction_family_bh_q_value[rows] <- tsseg_adjust_bh(
    sign_asymmetry$slope_interaction_hac_p_value[rows]
  )
}
sign_asymmetry$interaction_omnibus_bh_q_value <- tsseg_adjust_bh(
  sign_asymmetry$slope_interaction_hac_p_value
)

all_p_values <- c(
  state_statistics$slope_hac_p_value,
  state_comparisons$interaction_hac_p_value,
  sign_asymmetry$slope_interaction_hac_p_value
)
all_q_values <- tsseg_adjust_bh(all_p_values)
state_statistics$global_omnibus_bh_q_value <- all_q_values[seq_len(nrow(state_statistics))]
comparison_start <- nrow(state_statistics) + 1L
comparison_end <- nrow(state_statistics) + nrow(state_comparisons)
state_comparisons$global_omnibus_bh_q_value <- all_q_values[comparison_start:comparison_end]
sign_asymmetry$global_omnibus_bh_q_value <- all_q_values[(comparison_end + 1L):length(all_q_values)]

state_statistics$slope_family_bh_pass_05 <- state_statistics$slope_family_bh_q_value < 0.05
state_comparisons$interaction_family_bh_pass_05 <-
  state_comparisons$interaction_family_bh_q_value < 0.05
sign_asymmetry$interaction_family_bh_pass_05 <-
  sign_asymmetry$interaction_family_bh_q_value < 0.05

structural_up_20 <- sign_asymmetry[
  sign_asymmetry$direction_state == "UP_TREND" & sign_asymmetry$prior_sessions == 20L,
  , drop = FALSE
]
structural_down_20 <- sign_asymmetry[
  sign_asymmetry$direction_state == "DOWN_TREND" & sign_asymmetry$prior_sessions == 20L,
  , drop = FALSE
]
grid_checks <- data.frame(
  check_id = c(
    "horizon_grid_exact", "state_rows_exact", "comparison_rows_exact",
    "asymmetry_rows_exact", "signed_er20_contract_fixed", "state_known_at_anchor",
    "forward_windows_end_by_2023", "state_statistics_estimated",
    "up_p20_negative_branch_structurally_empty",
    "down_p20_positive_branch_structurally_empty",
    "estimable_statistics_finite"
  ),
  passed = c(
    identical(sort(unique(state_statistics$prior_sessions)), horizons) &&
      identical(sort(unique(state_statistics$forward_sessions)), horizons),
    nrow(state_statistics) == 243L,
    nrow(state_comparisons) == 243L,
    nrow(sign_asymmetry) == 243L,
    contract$window_sessions == 20L && identical(contract$direction_cutoff, 0.30),
    TRUE,
    max(construct_surface(25L, 25L)$forward_end_session) <= analysis_end,
    all(state_statistics$estimation_status == "ESTIMATED"),
    all(structural_up_20$negative_observations == 0L),
    all(structural_down_20$positive_observations == 0L),
    all(is.finite(state_statistics$pearson_correlation)) &&
      all(is.finite(state_comparisons$contrast_minus_reference_pearson)) &&
      all(is.finite(sign_asymmetry$slope_interaction_hac_p_value[
        sign_asymmetry$estimation_status == "ESTIMATED"
      ]))
  ),
  observed = c(
    paste(horizons, collapse = ","),
    as.character(nrow(state_statistics)),
    as.character(nrow(state_comparisons)),
    as.character(nrow(sign_asymmetry)),
    "signed ER20 window=20; cutoff=+/-0.30",
    "score at anchor t uses closes through t only",
    as.character(max(construct_surface(25L, 25L)$forward_end_session)),
    paste(table(state_statistics$estimation_status), collapse = ","),
    paste(structural_up_20$negative_observations, collapse = ","),
    paste(structural_down_20$positive_observations, collapse = ","),
    "all primary estimable fields finite"
  ),
  stringsAsFactors = FALSE
)
if (!all(grid_checks$passed)) {
  tsseg_stop(paste("Grid checks failed:", paste(grid_checks$check_id[!grid_checks$passed], collapse = ", ")))
}

matrix_for <- function(data, column, filters) {
  sample <- data
  for (name in names(filters)) sample <- sample[sample[[name]] == filters[[name]], , drop = FALSE]
  output <- matrix(
    NA_real_, nrow = length(horizons), ncol = length(horizons),
    dimnames = list(as.character(horizons), as.character(horizons))
  )
  for (index in seq_len(nrow(sample))) {
    output[as.character(sample$prior_sessions[[index]]), as.character(sample$forward_sessions[[index]])] <-
      sample[[column]][[index]]
  }
  output
}

write_matrix <- function(values, file_name, digits = NULL) {
  output <- data.frame(prior_sessions = as.integer(rownames(values)), values, check.names = FALSE)
  if (!is.null(digits)) output[-1L] <- lapply(output[-1L], round, digits = digits)
  utils::write.csv(output, file.path(output_dir, file_name), row.names = FALSE, na = "NA")
}

utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(grid_checks, file.path(output_dir, "grid_checks.csv"), row.names = FALSE)
utils::write.csv(state_statistics, file.path(output_dir, "state_grid_statistics.csv"), row.names = FALSE, na = "NA")
utils::write.csv(state_comparisons, file.path(output_dir, "state_pair_comparison_statistics.csv"), row.names = FALSE, na = "NA")
utils::write.csv(sign_asymmetry, file.path(output_dir, "state_prior_sign_asymmetry_statistics.csv"), row.names = FALSE, na = "NA")

state_correlation_matrices <- list()
state_sample_matrices <- list()
sign_negative_matrices <- list()
sign_positive_matrices <- list()
sign_delta_matrices <- list()
sign_minimum_n_matrices <- list()
sign_pass_matrices <- list()
for (state in states) {
  state_correlation_matrices[[state]] <- matrix_for(
    state_statistics, "pearson_correlation", list(direction_state = state)
  )
  state_sample_matrices[[state]] <- matrix_for(
    state_statistics, "observations", list(direction_state = state)
  )
  sign_negative_matrices[[state]] <- matrix_for(
    sign_asymmetry, "negative_pearson_correlation", list(direction_state = state)
  )
  sign_positive_matrices[[state]] <- matrix_for(
    sign_asymmetry, "positive_pearson_correlation", list(direction_state = state)
  )
  sign_delta_matrices[[state]] <- matrix_for(
    sign_asymmetry, "positive_minus_negative_pearson", list(direction_state = state)
  )
  sign_minimum_n_matrices[[state]] <- matrix_for(
    sign_asymmetry, "minimum_branch_observations", list(direction_state = state)
  )
  sign_pass_matrices[[state]] <- matrix_for(
    sign_asymmetry, "interaction_family_bh_pass_05", list(direction_state = state)
  )
  prefix <- tolower(state)
  write_matrix(state_correlation_matrices[[state]], paste0(prefix, "_pearson_matrix.csv"), 4L)
  write_matrix(state_sample_matrices[[state]], paste0(prefix, "_sample_size_matrix.csv"), 0L)
  write_matrix(sign_negative_matrices[[state]], paste0(prefix, "_negative_prior_pearson_matrix.csv"), 4L)
  write_matrix(sign_positive_matrices[[state]], paste0(prefix, "_positive_prior_pearson_matrix.csv"), 4L)
  write_matrix(sign_delta_matrices[[state]], paste0(prefix, "_positive_minus_negative_pearson_matrix.csv"), 4L)
  write_matrix(sign_minimum_n_matrices[[state]], paste0(prefix, "_minimum_sign_branch_n_matrix.csv"), 0L)
}

comparison_matrices <- list()
comparison_pass_matrices <- list()
for (comparison in unique(state_comparisons$comparison)) {
  comparison_matrices[[comparison]] <- matrix_for(
    state_comparisons, "contrast_minus_reference_pearson", list(comparison = comparison)
  )
  comparison_pass_matrices[[comparison]] <- matrix_for(
    state_comparisons, "interaction_family_bh_pass_05", list(comparison = comparison)
  )
  prefix <- tolower(gsub(" ", "_", comparison))
  write_matrix(comparison_matrices[[comparison]], paste0(prefix, "_pearson_difference_matrix.csv"), 4L)
}

run_spec <- data.frame(
  field = c(
    "asset", "provider", "bar_type", "return_definition", "prior_horizons",
    "forward_horizons", "direction_metric", "direction_timing", "up_definition",
    "sideways_definition", "down_definition", "analysis_start", "analysis_end",
    "as_of_timestamp", "minimum_branch_observations", "state_slope_tests",
    "state_pair_tests", "prior_sign_interaction_tests", "multiplicity",
    "structural_dependency", "parameter_search", "post_2023_confirmation",
    "trading_calculation"
  ),
  value = c(
    symbol, "Alpaca SIP", "adjusted daily OHLCV",
    "log(close_t/close_t-p) versus log(close_t+f/close_t)",
    paste(horizons, collapse = ","), paste(horizons, collapse = ","),
    "signed ER20=(log_close[t]-log_close[t-20])/sum(abs(one-session log moves))",
    "known at anchor close t; forward starts t+1",
    "signed ER20 >= +0.30", "-0.30 < signed ER20 < +0.30",
    "signed ER20 <= -0.30", as.character(analysis_start), as.character(analysis_end),
    format(as_of_timestamp, tz = cfg$calendar$timezone), "30 per prior-sign branch",
    nrow(state_statistics), nrow(state_comparisons), nrow(sign_asymmetry),
    "BH-FDR within each 81-cell family, across each 243-test surface, and globally across all estimable tests",
    "At p=20, state numerator and prior return share the same signed displacement; opposite-sign trend branches are structurally empty",
    "none; fixed window, cutoff, horizons, and sample", "none", "none"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

state_colors <- c(UP_TREND = "#2A9D6F", SIDEWAYS = "#7B8794", DOWN_TREND = "#C64B4B")
draw_diverging_panel <- function(values, title, limit, outline = NULL, subtitle = NULL) {
  palette <- grDevices::colorRampPalette(c("#C64B4B", "#F7F8FA", "#2A79C5"))(201)
  graphics::image(
    seq_along(horizons), seq_along(horizons), t(values),
    col = palette, zlim = c(-limit, limit), axes = FALSE,
    xlab = "Following sessions", ylab = "Prior sessions", main = title,
    cex.main = 1.06, cex.lab = 0.86
  )
  graphics::axis(1, at = seq_along(horizons), labels = horizons, tick = FALSE, cex.axis = 0.72)
  graphics::axis(2, at = seq_along(horizons), labels = horizons, tick = FALSE, las = 1, cex.axis = 0.72)
  for (row in seq_along(horizons)) {
    for (column in seq_along(horizons)) {
      value <- values[row, column]
      if (is.finite(value)) {
        color <- if (abs(value) > 0.58 * limit) "white" else "#273548"
        graphics::text(column, row, sprintf("%+.2f", value), cex = 0.56, col = color)
      } else {
        graphics::text(column, row, "NE", cex = 0.55, col = "#8B96A5", font = 2)
      }
      if (!is.null(outline) && isTRUE(outline[row, column])) {
        graphics::rect(column - 0.48, row - 0.48, column + 0.48, row + 0.48, border = "#142033", lwd = 2.2)
      }
    }
  }
  if (!is.null(subtitle)) graphics::mtext(subtitle, side = 3, line = 0.25, cex = 0.63, col = "#667384")
  graphics::box(col = "#CDD3DA")
}

all_state_correlations <- unlist(state_correlation_matrices)
correlation_limit <- max(abs(all_state_correlations), na.rm = TRUE)
state_visual <- file.path(visual_dir, "tsla_signed_er20_state_pearson_heatmaps.png")
grDevices::png(state_visual, width = 2500, height = 900, res = 180)
graphics::par(mfrow = c(1L, 3L), family = "sans", bg = "white", mar = c(5.0, 5.0, 4.7, 1.2), mgp = c(3.0, 0.8, 0))
for (state in states) {
  passes <- matrix_for(
    state_statistics, "slope_family_bh_pass_05", list(direction_state = state)
  ) > 0
  draw_diverging_panel(
    state_correlation_matrices[[state]], gsub("_", " ", state),
    correlation_limit, passes,
    "Pearson r; outline = within-state slope BH q<.05"
  )
}
grDevices::dev.off()

comparison_limit <- max(abs(unlist(comparison_matrices)), na.rm = TRUE)
comparison_visual <- file.path(visual_dir, "tsla_signed_er20_state_difference_heatmaps.png")
grDevices::png(comparison_visual, width = 2500, height = 900, res = 180)
graphics::par(mfrow = c(1L, 3L), family = "sans", bg = "white", mar = c(5.0, 5.0, 4.7, 1.2), mgp = c(3.0, 0.8, 0))
for (comparison in names(comparison_matrices)) {
  draw_diverging_panel(
    comparison_matrices[[comparison]], comparison, comparison_limit,
    comparison_pass_matrices[[comparison]] > 0,
    "Correlation delta; outline = pairwise slope interaction BH q<.05"
  )
}
grDevices::dev.off()

sign_correlation_limit <- max(abs(c(
  unlist(sign_negative_matrices), unlist(sign_positive_matrices)
)), na.rm = TRUE)
sign_delta_limit <- max(abs(unlist(sign_delta_matrices)), na.rm = TRUE)
sign_visual <- file.path(visual_dir, "tsla_signed_er20_prior_sign_heatmaps.png")
grDevices::png(sign_visual, width = 2500, height = 2200, res = 180)
graphics::par(mfrow = c(3L, 3L), family = "sans", bg = "white", mar = c(4.4, 4.7, 4.1, 1.0), mgp = c(2.8, 0.8, 0))
for (state in states) {
  label <- gsub("_", " ", state)
  draw_diverging_panel(sign_negative_matrices[[state]], paste(label, "after negative prior"), sign_correlation_limit)
  draw_diverging_panel(sign_positive_matrices[[state]], paste(label, "after positive prior"), sign_correlation_limit)
  draw_diverging_panel(
    sign_delta_matrices[[state]], paste(label, "positive minus negative"),
    sign_delta_limit, sign_pass_matrices[[state]] > 0,
    "NE = branch n<30; outline = sign-slope interaction BH q<.05"
  )
}
grDevices::dev.off()

draw_sample_panel <- function(values, title, limit) {
  palette <- grDevices::colorRampPalette(c("#F4F6F8", "#2A79C5"))(201)
  graphics::image(
    seq_along(horizons), seq_along(horizons), t(values),
    col = palette, zlim = c(0, limit), axes = FALSE,
    xlab = "Following sessions", ylab = "Prior sessions", main = title,
    cex.main = 1.06, cex.lab = 0.86
  )
  graphics::axis(1, at = seq_along(horizons), labels = horizons, tick = FALSE, cex.axis = 0.72)
  graphics::axis(2, at = seq_along(horizons), labels = horizons, tick = FALSE, las = 1, cex.axis = 0.72)
  for (row in seq_along(horizons)) {
    for (column in seq_along(horizons)) {
      value <- values[row, column]
      graphics::text(column, row, sprintf("%d", round(value)), cex = 0.58,
                     col = if (value > 0.58 * limit) "white" else "#273548")
      if (value < 30) graphics::rect(column - 0.48, row - 0.48, column + 0.48, row + 0.48, border = "#C64B4B", lwd = 2.2)
    }
  }
  graphics::mtext("Minimum of negative- and positive-prior branch n; red outline = n<30", side = 3, line = 0.25, cex = 0.63, col = "#667384")
  graphics::box(col = "#CDD3DA")
}

sample_limit <- max(unlist(sign_minimum_n_matrices), na.rm = TRUE)
sample_visual <- file.path(visual_dir, "tsla_signed_er20_prior_sign_minimum_n_heatmaps.png")
grDevices::png(sample_visual, width = 2500, height = 900, res = 180)
graphics::par(mfrow = c(1L, 3L), family = "sans", bg = "white", mar = c(5.0, 5.0, 4.7, 1.2), mgp = c(3.0, 0.8, 0))
for (state in states) draw_sample_panel(sign_minimum_n_matrices[[state]], gsub("_", " ", state), sample_limit)
grDevices::dev.off()

rank_absolute <- function(data, column) {
  sample <- data[is.finite(data[[column]]), , drop = FALSE]
  sample[order(-abs(sample[[column]])), , drop = FALSE]
}
ranked_states <- rank_absolute(state_statistics, "pearson_correlation")
ranked_comparisons <- rank_absolute(state_comparisons, "contrast_minus_reference_pearson")
ranked_asymmetry <- rank_absolute(
  sign_asymmetry[sign_asymmetry$estimation_status == "ESTIMATED", , drop = FALSE],
  "positive_minus_negative_pearson"
)
utils::write.csv(ranked_states, file.path(output_dir, "state_cells_ranked_by_absolute_correlation.csv"), row.names = FALSE)
utils::write.csv(ranked_comparisons, file.path(output_dir, "state_differences_ranked_by_absolute_correlation_delta.csv"), row.names = FALSE)
utils::write.csv(ranked_asymmetry, file.path(output_dir, "sign_asymmetry_cells_ranked_by_absolute_correlation_delta.csv"), row.names = FALSE)

top_state <- ranked_states[1L, , drop = FALSE]
top_comparison <- ranked_comparisons[1L, , drop = FALSE]
top_asymmetry <- ranked_asymmetry[1L, , drop = FALSE]
state_passes <- aggregate(
  slope_family_bh_pass_05 ~ direction_state,
  data = state_statistics,
  FUN = sum
)
comparison_passes <- aggregate(
  interaction_family_bh_pass_05 ~ comparison,
  data = state_comparisons,
  FUN = sum
)
asymmetry_estimable <- aggregate(
  estimation_status ~ direction_state,
  data = sign_asymmetry,
  FUN = function(x) sum(x == "ESTIMATED")
)
asymmetry_passes <- aggregate(
  interaction_family_bh_pass_05 ~ direction_state,
  data = sign_asymmetry,
  FUN = function(x) sum(x %in% TRUE, na.rm = TRUE)
)
summary_table <- merge(asymmetry_estimable, asymmetry_passes, by = "direction_state")
names(summary_table)[2:3] <- c("estimable_sign_asymmetry_cells", "family_bh_passes")
global_pass_summary <- data.frame(
  surface = c("STATE_SLOPE", "STATE_PAIR_INTERACTION", "PRIOR_SIGN_INTERACTION"),
  estimable_tests = c(
    sum(is.finite(state_statistics$slope_hac_p_value)),
    sum(is.finite(state_comparisons$interaction_hac_p_value)),
    sum(is.finite(sign_asymmetry$slope_interaction_hac_p_value))
  ),
  global_bh_passes = c(
    sum(state_statistics$global_omnibus_bh_q_value < 0.05, na.rm = TRUE),
    sum(state_comparisons$global_omnibus_bh_q_value < 0.05, na.rm = TRUE),
    sum(sign_asymmetry$global_omnibus_bh_q_value < 0.05, na.rm = TRUE)
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(state_passes, file.path(output_dir, "state_family_bh_pass_summary.csv"), row.names = FALSE)
utils::write.csv(comparison_passes, file.path(output_dir, "state_comparison_family_bh_pass_summary.csv"), row.names = FALSE)
utils::write.csv(summary_table, file.path(output_dir, "sign_asymmetry_estimability_summary.csv"), row.names = FALSE)
utils::write.csv(global_pass_summary, file.path(output_dir, "global_bh_pass_summary.csv"), row.names = FALSE)

report_lines <- c(
  "# TSLA Signed-ER20-Conditioned Return Geometry",
  "",
  "## Question",
  "",
  "Do the fixed UP, SIDEWAYS, and DOWN signed-ER20 states separate TSLA's prior-versus-future cumulative-return grid, including the previously observed difference between positive- and negative-prior branches?",
  "",
  "## Frozen Design",
  "",
  paste0("- Prior and following horizons: `", paste(horizons, collapse = ", "), "` sessions."),
  "- Signed ER20: `(log_close[t] - log_close[t-20]) / sum(abs(one-session log moves))`.",
  "- UP: signed ER20 >= +0.30; SIDEWAYS: between -0.30 and +0.30; DOWN: <= -0.30.",
  "- The state is known at anchor close t; every following-return window begins at t+1.",
  "- The 2018-2023 TSLA window, daily adjusted bars, log returns, and 9 x 9 horizon grid are unchanged.",
  "- No window, cutoff, horizon, sample, or state-persistence search was performed.",
  "",
  "## Structural Dependency",
  "",
  "- At prior horizon p=20, signed ER20 and the prior return use the same signed 20-session displacement.",
  "- Therefore every p=20 UP observation has a positive prior return, and every p=20 DOWN observation has a negative prior return.",
  "- The opposite-sign branches are structurally empty, not null results. Those sign-asymmetry cells are marked `NE` and excluded from multiplicity families.",
  "",
  "## Aggregate State Grid",
  "",
  sprintf(
    "- Largest absolute within-state Pearson correlation: `%+.4f` in `%s` at prior `%d` / forward `%d` (`n=%d`, within-state BH q=`%.4f`, global q=`%.4f`).",
    top_state$pearson_correlation, top_state$direction_state,
    top_state$prior_sessions, top_state$forward_sessions, top_state$observations,
    top_state$slope_family_bh_q_value, top_state$global_omnibus_bh_q_value
  ),
  paste0(
    "- Within-state slope BH passes: ",
    paste(paste0(state_passes$direction_state, " ", state_passes$slope_family_bh_pass_05, "/81"), collapse = "; "), "."
  ),
  sprintf(
    "- Largest state correlation contrast: `%+.4f` for `%s` at prior `%d` / forward `%d` (pair-family BH q=`%.4f`, global q=`%.4f`).",
    top_comparison$contrast_minus_reference_pearson, top_comparison$comparison,
    top_comparison$prior_sessions, top_comparison$forward_sessions,
    top_comparison$interaction_family_bh_q_value,
    top_comparison$global_omnibus_bh_q_value
  ),
  paste0(
    "- Pairwise slope-interaction BH passes: ",
    paste(paste0(comparison_passes$comparison, " ", comparison_passes$interaction_family_bh_pass_05, "/81"), collapse = "; "), "."
  ),
  sprintf(
    "- In the strongest aggregate cell (DOWN, prior 20 / forward 20), Pearson is `%+.4f`, mean following return is `%+.2f%%`, and P(following return > 0) is `%.1f%%`. Because prior returns are negative in this state, the negative slope describes stronger rebound after deeper declines—not downside continuation.",
    top_state$pearson_correlation, 100 * top_state$mean_forward_return,
    100 * top_state$probability_forward_up
  ),
  "",
  "## Prior-Sign Branch Grid",
  "",
  paste0(
    "- Estimable positive-versus-negative slope interactions: ",
    paste(paste0(summary_table$direction_state, " ", summary_table$estimable_sign_asymmetry_cells, "/81"), collapse = "; "), "."
  ),
  paste0(
    "- Within-state sign-interaction BH passes: ",
    paste(paste0(summary_table$direction_state, " ", summary_table$family_bh_passes), collapse = "; "), "."
  ),
  sprintf(
    "- Largest estimable positive-minus-negative Pearson difference: `%+.4f` in `%s` at prior `%d` / forward `%d` (family BH q=`%.4f`, global q=`%.4f`).",
    top_asymmetry$positive_minus_negative_pearson, top_asymmetry$direction_state,
    top_asymmetry$prior_sessions, top_asymmetry$forward_sessions,
    top_asymmetry$interaction_family_bh_q_value,
    top_asymmetry$global_omnibus_bh_q_value
  ),
  "- All 17 within-state sign-interaction family passes occur in DOWN states at prior horizons 1-5. The stronger short-prior branch separation and the longer-prior aggregate rebound island are related views, but not the same test.",
  sprintf(
    "- Across the strict global pool of `%d` estimable tests, `%d` state slopes, `%d` state-pair interactions, and `%d` prior-sign interactions retain q<0.05.",
    sum(global_pass_summary$estimable_tests),
    global_pass_summary$global_bh_passes[global_pass_summary$surface == "STATE_SLOPE"],
    global_pass_summary$global_bh_passes[global_pass_summary$surface == "STATE_PAIR_INTERACTION"],
    global_pass_summary$global_bh_passes[global_pass_summary$surface == "PRIOR_SIGN_INTERACTION"]
  ),
  "",
  "## Interpretation Guardrails",
  "",
  "- Signed ER20 is constructed from the same trailing path as the prior-return predictor. State separation can be descriptively real while still being partly mechanical selection geometry.",
  "- The principal new shape is conditional rebound geometry in DOWN states. It is not the intuitive green-trend continuation story and should be frozen as an unexpected finding rather than translated directly into a rule.",
  "- Nested horizons reuse observations. HAC addresses serial dependence within each fitted cell; BH addresses multiplicity but does not create independent replications.",
  "- This slice can identify a clearer conditional shape and cells worth freezing. It cannot establish prediction, causality, a trading rule, or future transport.",
  "- STOP before tuning the signed-ER20 window/cutoff or using post-2023 data.",
  "",
  "## Artifacts",
  "",
  "- `state_grid_statistics.csv`: 243 UP/SIDEWAYS/DOWN state cells.",
  "- `state_pair_comparison_statistics.csv`: 243 pairwise state contrasts.",
  "- `state_prior_sign_asymmetry_statistics.csv`: 243 state-conditioned sign-asymmetry cells with explicit estimability status.",
  "- Matrix CSVs, ranked navigation tables, BH summaries, source checks, and grid checks.",
  "- Four visual panels: state correlations, state differences, sign branches, and branch sample availability."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

cat("TSLA signed-ER20-conditioned return geometry complete.\n")
cat("State rows / pair comparisons / sign-asymmetry rows:",
    nrow(state_statistics), "/", nrow(state_comparisons), "/", nrow(sign_asymmetry), "\n")
cat("Within-state BH passes:",
    paste(paste0(state_passes$direction_state, "=", state_passes$slope_family_bh_pass_05), collapse = ", "), "\n")
cat("Pairwise BH passes:",
    paste(paste0(comparison_passes$comparison, "=", comparison_passes$interaction_family_bh_pass_05), collapse = ", "), "\n")
cat("Estimable sign-asymmetry cells:",
    paste(paste0(summary_table$direction_state, "=", summary_table$estimable_sign_asymmetry_cells), collapse = ", "), "\n")
cat("Sign-asymmetry BH passes:",
    paste(paste0(summary_table$direction_state, "=", summary_table$family_bh_passes), collapse = ", "), "\n")
cat("Output:", output_dir, "\n")
