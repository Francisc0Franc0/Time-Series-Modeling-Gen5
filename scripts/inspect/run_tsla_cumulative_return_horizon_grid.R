# Explore cumulative prior-versus-forward TSLA daily log returns across a
# predeclared 9 x 9 horizon grid. This is a descriptive navigation slice:
# no cell selection becomes a model, trading rule, or performance claim.

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
g5_load_local_renviron(repo_root)

cfg <- g5_load_data_layer_config(repo_root)
symbol <- "TSLA"
horizons <- c(1L, 2L, 3L, 4L, 5L, 10L, 15L, 20L, 25L)
query_start <- as.Date("2017-10-02")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
as_of_timestamp <- as.POSIXct("2026-08-24 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(
  tolower(Sys.getenv("GEN5_TSLA_RETURN_HORIZON_GRID_REFRESH", unset = "false")),
  "true"
)

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_cumulative_return_horizon_grid_20260825"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create TSLA horizon-grid output directory.", call. = FALSE)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "tsla_cumulative_return_horizon_grid",
  universe_roles = "single_asset_descriptive_horizon_grid",
  refresh = refresh,
  repo_root = repo_root
)

bars <- query$bars
bars <- bars[bars$symbol == symbol, , drop = FALSE]
bars$session_date <- as.Date(bars$session_date)
bars <- bars[order(bars$session_date), , drop = FALSE]

source_checks <- data.frame(
  check_id = c(
    "exact_symbol", "unique_sessions", "strict_date_order", "positive_finite_close",
    "adjusted_daily_only", "warmup_covered", "analysis_end_covered", "future_rows_absent"
  ),
  passed = c(
    nrow(bars) > 0L && identical(unique(as.character(bars$symbol)), symbol),
    !anyDuplicated(bars$session_date),
    nrow(bars) > 1L && all(diff(bars$session_date) > 0),
    nrow(bars) > 0L && all(is.finite(bars$close) & bars$close > 0),
    nrow(bars) > 0L && all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
    nrow(bars) > 0L && min(bars$session_date) <= query_start,
    nrow(bars) > 0L && max(bars$session_date) >= analysis_end,
    nrow(bars) > 0L && max(bars$session_date) <= analysis_end
  ),
  observed = c(
    paste(unique(as.character(bars$symbol)), collapse = ","),
    as.character(sum(duplicated(bars$session_date))),
    if (nrow(bars)) paste(min(bars$session_date), max(bars$session_date), sep = " to ") else "no rows",
    if (nrow(bars)) paste(range(bars$close), collapse = " to ") else "no rows",
    paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
    if (nrow(bars)) as.character(min(bars$session_date)) else "no rows",
    if (nrow(bars)) as.character(max(bars$session_date)) else "no rows",
    if (nrow(bars)) as.character(max(bars$session_date)) else "no rows"
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  failed <- source_checks$check_id[!source_checks$passed]
  stop("TSLA horizon-grid source checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

hac_vcov <- function(fit, lag) {
  design <- stats::model.matrix(fit)
  residuals <- stats::residuals(fit)
  n_obs <- nrow(design)
  n_coef <- ncol(design)
  lag <- min(as.integer(lag), n_obs - 1L)
  meat <- matrix(0, nrow = n_coef, ncol = n_coef)
  for (t in seq_len(n_obs)) {
    xt <- matrix(design[t, ], ncol = 1L)
    meat <- meat + residuals[[t]]^2 * (xt %*% t(xt))
  }
  if (lag > 0L) {
    for (ell in seq_len(lag)) {
      weight <- 1 - ell / (lag + 1)
      gamma <- matrix(0, nrow = n_coef, ncol = n_coef)
      for (t in seq.int(ell + 1L, n_obs)) {
        xt <- matrix(design[t, ], ncol = 1L)
        xlag <- matrix(design[t - ell, ], ncol = 1L)
        gamma <- gamma + residuals[[t]] * residuals[[t - ell]] * (xt %*% t(xlag))
      }
      meat <- meat + weight * (gamma + t(gamma))
    }
  }
  bread <- solve(crossprod(design))
  correction <- n_obs / (n_obs - n_coef)
  correction * bread %*% meat %*% bread
}

construct_pair_surface <- function(prior_sessions, forward_sessions) {
  anchor_indices <- seq_len(nrow(bars))
  usable <-
    anchor_indices - prior_sessions >= 1L &
    anchor_indices + forward_sessions <= nrow(bars)
  anchor_indices <- anchor_indices[usable]
  forward_start_dates <- bars$session_date[anchor_indices + 1L]
  forward_end_dates <- bars$session_date[anchor_indices + forward_sessions]
  in_window <- forward_start_dates >= analysis_start & forward_end_dates <= analysis_end
  anchor_indices <- anchor_indices[in_window]
  if (!length(anchor_indices)) stop("No complete horizon-grid observations.", call. = FALSE)

  prior_return <- log(bars$close[anchor_indices] / bars$close[anchor_indices - prior_sessions])
  forward_return <- log(bars$close[anchor_indices + forward_sessions] / bars$close[anchor_indices])
  data.frame(
    anchor_session = bars$session_date[anchor_indices],
    prior_start_session = bars$session_date[anchor_indices - prior_sessions],
    forward_start_session = bars$session_date[anchor_indices + 1L],
    forward_end_session = bars$session_date[anchor_indices + forward_sessions],
    prior_cumulative_log_return = prior_return,
    forward_cumulative_log_return = forward_return,
    stringsAsFactors = FALSE
  )
}

measure_cell <- function(prior_sessions, forward_sessions) {
  surface <- construct_pair_surface(prior_sessions, forward_sessions)
  x <- surface$prior_cumulative_log_return
  y <- surface$forward_cumulative_log_return
  n <- length(y)

  fit <- stats::lm(y ~ x)
  overlap_lag <- prior_sessions + forward_sessions - 1L
  rule_lag <- floor(4 * (n / 100)^(2 / 9))
  hac_lag <- max(overlap_lag, rule_lag)
  covariance <- hac_vcov(fit, hac_lag)
  se <- sqrt(diag(covariance))
  beta <- unname(stats::coef(fit)[[2L]])
  beta_z <- beta / se[[2L]]
  beta_p <- 2 * stats::pnorm(-abs(beta_z))
  beta_lower <- beta - stats::qnorm(0.975) * se[[2L]]
  beta_upper <- beta + stats::qnorm(0.975) * se[[2L]]

  pearson <- stats::cor(x, y, method = "pearson")
  correlation_scale <- stats::sd(x) / stats::sd(y)
  correlation_lower <- beta_lower * correlation_scale
  correlation_upper <- beta_upper * correlation_scale

  prior_up <- as.numeric(x > 0)
  forward_up <- as.numeric(y > 0)
  direction_fit <- stats::lm(forward_up ~ prior_up)
  direction_covariance <- hac_vcov(direction_fit, hac_lag)
  direction_se <- sqrt(diag(direction_covariance))[[2L]]
  direction_difference <- unname(stats::coef(direction_fit)[[2L]])
  direction_z <- direction_difference / direction_se
  direction_p <- 2 * stats::pnorm(-abs(direction_z))

  data.frame(
    prior_sessions = prior_sessions,
    forward_sessions = forward_sessions,
    observations = n,
    first_forward_session = min(surface$forward_start_session),
    last_forward_end_session = max(surface$forward_end_session),
    pearson_correlation = pearson,
    pearson_hac_lower_95 = correlation_lower,
    pearson_hac_upper_95 = correlation_upper,
    spearman_correlation = stats::cor(x, y, method = "spearman"),
    ols_intercept = unname(stats::coef(fit)[[1L]]),
    ols_slope = beta,
    slope_hac_standard_error = se[[2L]],
    slope_hac_lower_95 = beta_lower,
    slope_hac_upper_95 = beta_upper,
    slope_hac_p_value = beta_p,
    ols_r_squared = summary(fit)$r.squared,
    hac_lag = hac_lag,
    mean_prior_return = mean(x),
    mean_forward_return = mean(y),
    sd_prior_return = stats::sd(x),
    sd_forward_return = stats::sd(y),
    probability_forward_up = mean(forward_up),
    probability_forward_up_after_prior_up = mean(forward_up[prior_up == 1]),
    probability_forward_up_after_prior_down = mean(forward_up[prior_up == 0]),
    direction_difference = direction_difference,
    direction_hac_lower_95 = direction_difference - stats::qnorm(0.975) * direction_se,
    direction_hac_upper_95 = direction_difference + stats::qnorm(0.975) * direction_se,
    direction_hac_p_value = direction_p,
    same_sign_probability = mean((x > 0) == (y > 0)),
    stringsAsFactors = FALSE
  )
}

grid_rows <- vector("list", length(horizons)^2)
row_index <- 1L
for (prior_sessions in horizons) {
  for (forward_sessions in horizons) {
    grid_rows[[row_index]] <- measure_cell(prior_sessions, forward_sessions)
    row_index <- row_index + 1L
  }
}
grid <- do.call(rbind, grid_rows)
rownames(grid) <- NULL
grid$slope_bh_q_value <- stats::p.adjust(grid$slope_hac_p_value, method = "BH")
grid$slope_bonferroni_p_value <- pmin(1, grid$slope_hac_p_value * nrow(grid))
grid$direction_bh_q_value <- stats::p.adjust(grid$direction_hac_p_value, method = "BH")
grid$direction_bonferroni_p_value <- pmin(1, grid$direction_hac_p_value * nrow(grid))
grid$pearson_hac_interval_excludes_zero <-
  grid$pearson_hac_lower_95 > 0 | grid$pearson_hac_upper_95 < 0
grid$slope_bh_pass_05 <- grid$slope_bh_q_value < 0.05
grid$slope_bonferroni_pass_05 <- grid$slope_bonferroni_p_value < 0.05

if (nrow(grid) != 81L) stop("Horizon grid did not produce 81 cells.", call. = FALSE)
if (!all(is.finite(grid$pearson_correlation))) stop("Non-finite grid correlation.", call. = FALSE)
if (!all(grid$observations > 1400L)) stop("Unexpectedly small horizon-grid sample.", call. = FALSE)

one_by_one <- grid[grid$prior_sessions == 1L & grid$forward_sessions == 1L, , drop = FALSE]
grid_checks <- data.frame(
  check_id = c(
    "predeclared_horizons_exact", "cell_count_exact", "one_by_one_matches_prior_slice",
    "all_windows_nonoverlapping_in_information", "all_forward_windows_end_by_2023",
    "all_cells_have_large_samples", "all_statistics_finite"
  ),
  passed = c(
    identical(sort(unique(grid$prior_sessions)), horizons) &&
      identical(sort(unique(grid$forward_sessions)), horizons),
    nrow(grid) == 81L,
    nrow(one_by_one) == 1L && one_by_one$observations == 1509L &&
      abs(one_by_one$pearson_correlation - (-0.02104666)) < 1e-7,
    TRUE,
    max(as.Date(grid$last_forward_end_session)) <= analysis_end,
    min(grid$observations) > 1400L,
    all(vapply(grid, function(column) {
      if (is.numeric(column)) all(is.finite(column)) else TRUE
    }, logical(1)))
  ),
  observed = c(
    paste(horizons, collapse = ","),
    as.character(nrow(grid)),
    sprintf("n=%d, pearson=%.8f", one_by_one$observations, one_by_one$pearson_correlation),
    "prior window ends at anchor close; forward window begins after anchor close",
    as.character(max(as.Date(grid$last_forward_end_session))),
    paste(range(grid$observations), collapse = " to "),
    "all numeric fields finite"
  ),
  stringsAsFactors = FALSE
)
if (!all(grid_checks$passed)) {
  failed <- grid_checks$check_id[!grid_checks$passed]
  stop("TSLA horizon-grid checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

matrix_for <- function(column) {
  result <- matrix(
    NA_real_, nrow = length(horizons), ncol = length(horizons),
    dimnames = list(as.character(horizons), as.character(horizons))
  )
  for (i in seq_len(nrow(grid))) {
    result[as.character(grid$prior_sessions[[i]]), as.character(grid$forward_sessions[[i]])] <-
      grid[[column]][[i]]
  }
  result
}

write_matrix_csv <- function(values, file_name, digits = NULL) {
  output <- data.frame(prior_sessions = as.integer(rownames(values)), values, check.names = FALSE)
  if (!is.null(digits)) output[-1L] <- lapply(output[-1L], round, digits = digits)
  utils::write.csv(output, file.path(output_dir, file_name), row.names = FALSE)
}

pearson_matrix <- matrix_for("pearson_correlation")
spearman_matrix <- matrix_for("spearman_correlation")
slope_matrix <- matrix_for("ols_slope")
p_value_matrix <- matrix_for("slope_hac_p_value")
q_value_matrix <- matrix_for("slope_bh_q_value")
r_squared_percent_matrix <- 100 * matrix_for("ols_r_squared")
direction_difference_pp_matrix <- 100 * matrix_for("direction_difference")
sample_size_matrix <- matrix_for("observations")

utils::write.csv(grid, file.path(output_dir, "horizon_grid_statistics.csv"), row.names = FALSE)
utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(grid_checks, file.path(output_dir, "grid_checks.csv"), row.names = FALSE)
write_matrix_csv(pearson_matrix, "pearson_correlation_matrix.csv", 4L)
write_matrix_csv(spearman_matrix, "spearman_correlation_matrix.csv", 4L)
write_matrix_csv(slope_matrix, "ols_slope_matrix.csv", 4L)
write_matrix_csv(p_value_matrix, "slope_hac_p_value_matrix.csv", 5L)
write_matrix_csv(q_value_matrix, "slope_bh_q_value_matrix.csv", 5L)
write_matrix_csv(r_squared_percent_matrix, "r_squared_percent_matrix.csv", 3L)
write_matrix_csv(direction_difference_pp_matrix, "direction_difference_pp_matrix.csv", 2L)
write_matrix_csv(sample_size_matrix, "sample_size_matrix.csv", 0L)

ranked <- grid[order(-abs(grid$pearson_correlation)), , drop = FALSE]
ranked$absolute_pearson_correlation <- abs(ranked$pearson_correlation)
utils::write.csv(ranked, file.path(output_dir, "cells_ranked_by_absolute_correlation.csv"), row.names = FALSE)

run_spec <- data.frame(
  field = c(
    "asset", "provider", "bar_type", "return_definition", "prior_horizons",
    "forward_horizons", "analysis_start", "analysis_end", "as_of_timestamp",
    "cell_count", "primary_measure", "uncertainty", "hac_lag_rule",
    "multiplicity", "post_2023_confirmation", "trading_calculation"
  ),
  value = c(
    symbol, "Alpaca SIP", "adjusted daily OHLCV",
    "log(close_anchor/close_anchor_minus_p) versus log(close_anchor_plus_f/close_anchor)",
    paste(horizons, collapse = ","), paste(horizons, collapse = ","),
    as.character(analysis_start), as.character(analysis_end), format(as_of_timestamp, tz = cfg$calendar$timezone),
    nrow(grid), "Pearson correlation / OLS slope",
    "95% Newey-West/HAC intervals", "max(p+f-1, floor(4*(n/100)^(2/9)))",
    "Benjamini-Hochberg FDR and Bonferroni across 81 signed-return cells",
    "none", "none"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

plot_theme <- function() {
  graphics::par(
    family = "sans", bg = "white", fg = "#273548", col.axis = "#526070",
    col.lab = "#273548", mar = c(6.4, 6.9, 5.8, 3.0), mgp = c(3.9, 1.1, 0)
  )
}

draw_heatmap <- function(values, output_path, title, subtitle, label_format, limit = NULL,
                         negative_color = "#D95F5F", positive_color = "#3D8DFF",
                         outline = NULL, width = 1680, height = 1320) {
  if (is.null(limit)) limit <- max(abs(values), na.rm = TRUE)
  if (!is.finite(limit) || limit <= 0) limit <- 1
  palette <- grDevices::colorRampPalette(c(negative_color, "#F7F8FA", positive_color))(201)
  grDevices::png(output_path, width = width, height = height, res = 180)
  plot_theme()
  graphics::image(
    x = seq_along(horizons), y = seq_along(horizons), z = t(values),
    col = palette, zlim = c(-limit, limit), axes = FALSE,
    xlab = "Following sessions in cumulative log return",
    ylab = "Prior sessions in cumulative log return",
    main = title, cex.main = 1.45, cex.lab = 1.12
  )
  graphics::axis(1, at = seq_along(horizons), labels = horizons, tick = FALSE, cex.axis = 0.95)
  graphics::axis(2, at = seq_along(horizons), labels = horizons, tick = FALSE, las = 1, cex.axis = 0.95)
  for (row in seq_along(horizons)) {
    for (column in seq_along(horizons)) {
      value <- values[row, column]
      label_color <- if (abs(value) > 0.58 * limit) "white" else "#273548"
      graphics::text(column, row, labels = sprintf(label_format, value), cex = 0.78, col = label_color)
      if (!is.null(outline) && isTRUE(outline[row, column])) {
        graphics::rect(column - 0.48, row - 0.48, column + 0.48, row + 0.48, border = "#142033", lwd = 2.5)
      }
    }
  }
  graphics::mtext(subtitle, side = 3, line = 1.0, cex = 0.88, col = "#667384")
  graphics::box(col = "#CDD3DA")
  grDevices::dev.off()
}

fdr_outline <- matrix_for("slope_bh_pass_05") > 0
pearson_path <- file.path(visual_dir, "tsla_cumulative_return_pearson_heatmap.png")
draw_heatmap(
  pearson_matrix, pearson_path,
  "Signed return dependence across 81 horizon pairs",
  "Cell values are Pearson correlations; dark outlines mark BH-FDR q < 0.05",
  "%+.3f", outline = fdr_outline
)

direction_path <- file.path(visual_dir, "tsla_cumulative_return_direction_difference_heatmap.png")
draw_heatmap(
  direction_difference_pp_matrix, direction_path,
  "Prior-sign differences appear, but are not multiplicity-stable",
  "Percentage points: P(forward up | prior up) minus P(forward up | prior down); no BH-FDR passes",
  "%+.1f", width = 1800, height = 1050
)

r_squared_path <- file.path(visual_dir, "tsla_cumulative_return_r_squared_heatmap.png")
draw_heatmap(
  r_squared_percent_matrix, r_squared_path,
  "Explained variance remains small across the grid",
  "Cell values are OLS R-squared percentages; darker blue means more variance explained",
  "%.2f", limit = max(r_squared_percent_matrix), negative_color = "#F7F8FA",
  width = 1800, height = 1200
)

markdown_matrix <- function(values, digits = 3L, suffix = "") {
  header <- paste(c("Prior \\ Forward", colnames(values)), collapse = " | ")
  separator <- paste(c("---", rep("---:", ncol(values))), collapse = " | ")
  rows <- vapply(seq_len(nrow(values)), function(i) {
    formatted <- paste0(formatC(values[i, ], format = "f", digits = digits), suffix)
    paste(c(rownames(values)[[i]], formatted), collapse = " | ")
  }, character(1))
  paste(c(paste0("| ", header, " |"), paste0("| ", separator, " |"), paste0("| ", rows, " |")), collapse = "\n")
}

top_cells <- head(ranked, 10L)
top_lines <- vapply(seq_len(nrow(top_cells)), function(i) {
  row <- top_cells[i, ]
  sprintf(
    "| %d | %d | %+.4f | [%+.4f, %+.4f] | %.4f | %.4f | %.3f%% |",
    row$prior_sessions, row$forward_sessions, row$pearson_correlation,
    row$pearson_hac_lower_95, row$pearson_hac_upper_95,
    row$slope_hac_p_value, row$slope_bh_q_value, 100 * row$ols_r_squared
  )
}, character(1))

max_cell <- ranked[1L, , drop = FALSE]
bh_count <- sum(grid$slope_bh_pass_05)
bonferroni_count <- sum(grid$slope_bonferroni_pass_05)
direction_bh_count <- sum(grid$direction_bh_q_value < 0.05)
report_lines <- c(
  "# TSLA Cumulative Return Horizon Grid",
  "",
  "## Question",
  "",
  "Does cumulative signed return over more than one prior session contain a relationship with cumulative signed return over one or more following sessions that is hidden by the adjacent-session view?",
  "",
  "## Fixed Surface",
  "",
  paste0("- Prior horizons: `", paste(horizons, collapse = ", "), "` sessions."),
  paste0("- Forward horizons: `", paste(horizons, collapse = ", "), "` sessions."),
  "- Each prior window ends at the anchor close; each forward window starts after that close.",
  "- Analysis window: first forward session no earlier than `2018-01-02`; final forward session no later than `2023-12-29`.",
  "- Primary comparison: Pearson correlation / OLS slope.",
  "- Overlap-aware uncertainty: Newey-West/HAC with lag at least `p + f - 1`.",
  "- Multiplicity: BH-FDR and Bonferroni across the 81 signed-return cells.",
  "- No post-2023 data, model selection, trading rule, or performance calculation.",
  "",
  "## Pearson Correlation Matrix",
  "",
  markdown_matrix(pearson_matrix, digits = 3L),
  "",
  "## BH-FDR q-value Matrix",
  "",
  markdown_matrix(q_value_matrix, digits = 3L),
  "",
  "## Direction Difference Matrix",
  "",
  "Values are percentage-point differences in forward-up probability after a positive versus non-positive prior cumulative return.",
  "",
  markdown_matrix(direction_difference_pp_matrix, digits = 1L, suffix = " pp"),
  "",
  "## Ten Largest Absolute Pearson Correlations",
  "",
  "| Prior | Forward | Pearson | HAC 95% interval | HAC p | BH q | R-squared |",
  "|---:|---:|---:|---:|---:|---:|---:|",
  top_lines,
  "",
  "## Scan Readout",
  "",
  sprintf("- Largest absolute Pearson correlation: `%+.4f` at prior `%d` / forward `%d` sessions.", max_cell$pearson_correlation, max_cell$prior_sessions, max_cell$forward_sessions),
  sprintf("- Signed-return cells with BH-FDR q < 0.05: `%d` of `81`.", bh_count),
  sprintf("- Signed-return cells passing Bonferroni 0.05: `%d` of `81`.", bonferroni_count),
  sprintf("- Direction-difference cells with BH-FDR q < 0.05: `%d` of `81`.", direction_bh_count),
  "- Horizon cells are strongly dependent because their return windows are nested and overlapping. The table is a navigation surface, not 81 independent experiments.",
  "- Any visually interesting region must be converted into a new, narrowly frozen follow-up before detailed visualization or predictive interpretation.",
  "",
  "## Artifacts",
  "",
  "- `horizon_grid_statistics.csv`: complete one-row-per-cell table.",
  "- Matrix CSVs: Pearson, Spearman, OLS slope, HAC p, BH q, R-squared, direction difference, and sample size.",
  "- `cells_ranked_by_absolute_correlation.csv`: descriptive ranking for navigation.",
  "- `visuals/`: three overview heatmaps."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

cat("TSLA cumulative-return horizon grid complete.\n")
cat("Cells:", nrow(grid), "\n")
cat("Observations per cell:", min(grid$observations), "to", max(grid$observations), "\n")
cat("Largest absolute Pearson:", sprintf("%+.4f", max_cell$pearson_correlation),
    "at", max_cell$prior_sessions, "prior /", max_cell$forward_sessions, "forward\n")
cat("BH-FDR signed-return passes:", bh_count, "\n")
cat("Bonferroni signed-return passes:", bonferroni_count, "\n")
cat("Output:", output_dir, "\n")
