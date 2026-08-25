# Quantify the fixed TSLA t-1 versus t daily log-return relationship.
# This is a descriptive measurement slice: no horizon search, model selection,
# trading rule, performance claim, or post-2023 data.

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
query_start <- as.Date("2017-12-01")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
as_of_timestamp <- as.POSIXct("2026-08-24 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(tolower(Sys.getenv("GEN5_TSLA_RETURN_STATS_REFRESH", unset = "false")), "true")
bootstrap_replicates <- 5000L
bootstrap_block_length <- 20L
bootstrap_seed <- 20260825L
winsor_tail_probability <- 0.01

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_lagged_return_dependence_statistics_20260825"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create TSLA return-statistics output directory.", call. = FALSE)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "tsla_lagged_return_dependence_statistics",
  universe_roles = "single_asset_descriptive_measurement",
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
    "adjusted_daily_only", "query_start_covered", "analysis_end_covered", "future_rows_absent"
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
  stop("TSLA source checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

bars$log_return <- c(NA_real_, diff(log(bars$close)))
indices <- seq.int(3L, nrow(bars))
pairs <- data.frame(
  t_minus_1_session = bars$session_date[indices - 1L],
  t_session = bars$session_date[indices],
  log_return_t_minus_1 = bars$log_return[indices - 1L],
  log_return_t = bars$log_return[indices],
  stringsAsFactors = FALSE
)
pairs <- pairs[
  pairs$t_session >= analysis_start & pairs$t_session <= analysis_end &
    is.finite(pairs$log_return_t_minus_1) & is.finite(pairs$log_return_t),
  , drop = FALSE
]
if (!nrow(pairs)) stop("No complete consecutive-return pairs were constructed.", call. = FALSE)
if (any(pairs$t_minus_1_session >= pairs$t_session)) {
  stop("Consecutive-return pair dates are not strictly ordered.", call. = FALSE)
}

x <- pairs$log_return_t_minus_1
y <- pairs$log_return_t
n <- length(y)
previous_up <- x > 0
current_up <- y > 0

pair_checks <- data.frame(
  check_id = c(
    "expected_pair_count", "visible_window_exact", "finite_returns", "strict_pair_dates",
    "both_prior_directions", "both_current_directions", "no_post_2023_pairs"
  ),
  passed = c(
    n == 1509L,
    min(pairs$t_session) == analysis_start && max(pairs$t_session) == analysis_end,
    all(is.finite(x)) && all(is.finite(y)),
    all(pairs$t_minus_1_session < pairs$t_session),
    any(previous_up) && any(!previous_up),
    any(current_up) && any(!current_up),
    max(pairs$t_session) <= analysis_end
  ),
  observed = c(
    as.character(n),
    paste(min(pairs$t_session), max(pairs$t_session), sep = " to "),
    paste(range(c(x, y)), collapse = " to "),
    as.character(all(pairs$t_minus_1_session < pairs$t_session)),
    paste(sum(previous_up), sum(!previous_up), sep = " up / down="),
    paste(sum(current_up), sum(!current_up), sep = " up / down="),
    as.character(max(pairs$t_session))
  ),
  stringsAsFactors = FALSE
)
if (!all(pair_checks$passed)) {
  failed <- pair_checks$check_id[!pair_checks$passed]
  stop("TSLA pair checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

hac_vcov <- function(fit, lag = NULL) {
  design <- stats::model.matrix(fit)
  residuals <- stats::residuals(fit)
  n_obs <- nrow(design)
  n_coef <- ncol(design)
  if (is.null(lag)) lag <- floor(4 * (n_obs / 100)^(2 / 9))
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

metric_vector <- function(x_value, y_value) {
  prior_up <- x_value > 0
  next_up <- y_value > 0
  fit <- stats::lm(y_value ~ x_value)
  c(
    pearson = stats::cor(x_value, y_value, method = "pearson"),
    spearman = stats::cor(x_value, y_value, method = "spearman"),
    intercept = unname(stats::coef(fit)[[1L]]),
    slope = unname(stats::coef(fit)[[2L]]),
    r_squared = summary(fit)$r.squared,
    unconditional_up = mean(next_up),
    up_after_up = mean(next_up[prior_up]),
    up_after_down = mean(next_up[!prior_up]),
    direction_difference = mean(next_up[prior_up]) - mean(next_up[!prior_up]),
    direction_phi = stats::cor(as.numeric(prior_up), as.numeric(next_up)),
    absolute_pearson = stats::cor(abs(x_value), abs(y_value), method = "pearson"),
    absolute_spearman = stats::cor(abs(x_value), abs(y_value), method = "spearman"),
    squared_pearson = stats::cor(x_value^2, y_value^2, method = "pearson")
  )
}

observed_metrics <- metric_vector(x, y)
fit <- stats::lm(y ~ x)
hac_lag <- floor(4 * (n / 100)^(2 / 9))
hac_covariance <- hac_vcov(fit, lag = hac_lag)
hac_standard_errors <- sqrt(diag(hac_covariance))
hac_z <- stats::coef(fit) / hac_standard_errors
hac_p <- 2 * stats::pnorm(-abs(hac_z))
hac_ci <- cbind(
  lower = stats::coef(fit) - stats::qnorm(0.975) * hac_standard_errors,
  upper = stats::coef(fit) + stats::qnorm(0.975) * hac_standard_errors
)

circular_block_indices <- function(n_obs, block_length) {
  block_count <- ceiling(n_obs / block_length)
  starts <- sample.int(n_obs, block_count, replace = TRUE)
  indices <- unlist(lapply(starts, function(start) {
    ((start - 1L + seq.int(0L, block_length - 1L)) %% n_obs) + 1L
  }), use.names = FALSE)
  indices[seq_len(n_obs)]
}

set.seed(bootstrap_seed)
bootstrap_metrics <- matrix(
  NA_real_,
  nrow = bootstrap_replicates,
  ncol = length(observed_metrics),
  dimnames = list(NULL, names(observed_metrics))
)
for (b in seq_len(bootstrap_replicates)) {
  sampled <- circular_block_indices(n, bootstrap_block_length)
  bootstrap_metrics[b, ] <- metric_vector(x[sampled], y[sampled])
}
if (any(!is.finite(bootstrap_metrics))) {
  stop("Block bootstrap produced non-finite statistics.", call. = FALSE)
}

bootstrap_intervals <- do.call(rbind, lapply(names(observed_metrics), function(metric) {
  values <- bootstrap_metrics[, metric]
  data.frame(
    metric = metric,
    estimate = unname(observed_metrics[[metric]]),
    lower_95 = unname(stats::quantile(values, 0.025, names = FALSE, type = 8)),
    upper_95 = unname(stats::quantile(values, 0.975, names = FALSE, type = 8)),
    bootstrap_replicates = bootstrap_replicates,
    block_length_pairs = bootstrap_block_length,
    stringsAsFactors = FALSE
  )
}))

primary_stats <- data.frame(
  metric = c(
    "sample_size", "mean_return_t", "sd_return_t", "pearson_correlation",
    "spearman_correlation", "ols_intercept", "ols_slope", "ols_r_squared",
    "hac_lag", "hac_intercept_standard_error", "hac_slope_standard_error",
    "hac_intercept_p_value", "hac_slope_p_value", "hac_intercept_lower_95",
    "hac_intercept_upper_95", "hac_slope_lower_95", "hac_slope_upper_95",
    "absolute_return_pearson", "absolute_return_spearman", "squared_return_pearson"
  ),
  value = c(
    n, mean(y), stats::sd(y), observed_metrics[["pearson"]], observed_metrics[["spearman"]],
    stats::coef(fit)[[1L]], stats::coef(fit)[[2L]], summary(fit)$r.squared, hac_lag,
    hac_standard_errors[[1L]], hac_standard_errors[[2L]], hac_p[[1L]], hac_p[[2L]],
    hac_ci[1L, "lower"], hac_ci[1L, "upper"], hac_ci[2L, "lower"], hac_ci[2L, "upper"],
    observed_metrics[["absolute_pearson"]], observed_metrics[["absolute_spearman"]],
    observed_metrics[["squared_pearson"]]
  ),
  stringsAsFactors = FALSE
)

interval_for <- function(metric) bootstrap_intervals[bootstrap_intervals$metric == metric, , drop = FALSE]
direction_transition <- rbind(
  data.frame(
    condition = "Unconditional",
    observations = n,
    up_probability = observed_metrics[["unconditional_up"]],
    lower_95 = interval_for("unconditional_up")$lower_95,
    upper_95 = interval_for("unconditional_up")$upper_95,
    stringsAsFactors = FALSE
  ),
  data.frame(
    condition = "After prior down day",
    observations = sum(!previous_up),
    up_probability = observed_metrics[["up_after_down"]],
    lower_95 = interval_for("up_after_down")$lower_95,
    upper_95 = interval_for("up_after_down")$upper_95,
    stringsAsFactors = FALSE
  ),
  data.frame(
    condition = "After prior up day",
    observations = sum(previous_up),
    up_probability = observed_metrics[["up_after_up"]],
    lower_95 = interval_for("up_after_up")$lower_95,
    upper_95 = interval_for("up_after_up")$upper_95,
    stringsAsFactors = FALSE
  )
)
direction_difference <- data.frame(
  comparison = "P(up_t | up_t-1) minus P(up_t | down_t-1)",
  estimate = observed_metrics[["direction_difference"]],
  lower_95 = interval_for("direction_difference")$lower_95,
  upper_95 = interval_for("direction_difference")$upper_95,
  phi = observed_metrics[["direction_phi"]],
  stringsAsFactors = FALSE
)

winsorize <- function(values, tail_probability) {
  limits <- stats::quantile(values, c(tail_probability, 1 - tail_probability), names = FALSE, type = 8)
  pmin(pmax(values, limits[[1L]]), limits[[2L]])
}
x_winsor <- winsorize(x, winsor_tail_probability)
y_winsor <- winsorize(y, winsor_tail_probability)
winsor_metrics <- metric_vector(x_winsor, y_winsor)
outlier_sensitivity <- data.frame(
  sample = c("All observations", "1%/99% winsorized"),
  pearson = c(observed_metrics[["pearson"]], winsor_metrics[["pearson"]]),
  spearman = c(observed_metrics[["spearman"]], winsor_metrics[["spearman"]]),
  ols_slope = c(observed_metrics[["slope"]], winsor_metrics[["slope"]]),
  absolute_pearson = c(observed_metrics[["absolute_pearson"]], winsor_metrics[["absolute_pearson"]]),
  stringsAsFactors = FALSE
)

annual_rows <- split(seq_len(nrow(pairs)), format(pairs$t_session, "%Y"))
annual_stats <- do.call(rbind, lapply(names(annual_rows), function(year) {
  rows <- annual_rows[[year]]
  year_fit <- stats::lm(y[rows] ~ x[rows])
  year_lag <- floor(4 * (length(rows) / 100)^(2 / 9))
  year_covariance <- hac_vcov(year_fit, lag = year_lag)
  year_se <- sqrt(diag(year_covariance))[[2L]]
  year_beta <- stats::coef(year_fit)[[2L]]
  data.frame(
    period = year,
    observations = length(rows),
    pearson = stats::cor(x[rows], y[rows]),
    ols_slope = year_beta,
    slope_hac_lower_95 = year_beta - stats::qnorm(0.975) * year_se,
    slope_hac_upper_95 = year_beta + stats::qnorm(0.975) * year_se,
    hac_lag = year_lag,
    direction_difference = mean(y[rows][x[rows] > 0] > 0) - mean(y[rows][x[rows] <= 0] > 0),
    absolute_pearson = stats::cor(abs(x[rows]), abs(y[rows])),
    stringsAsFactors = FALSE
  )
}))
rownames(annual_stats) <- NULL
full_period_row <- data.frame(
  period = "2018-2023",
  observations = n,
  pearson = observed_metrics[["pearson"]],
  ols_slope = observed_metrics[["slope"]],
  slope_hac_lower_95 = hac_ci[2L, "lower"],
  slope_hac_upper_95 = hac_ci[2L, "upper"],
  hac_lag = hac_lag,
  direction_difference = observed_metrics[["direction_difference"]],
  absolute_pearson = observed_metrics[["absolute_pearson"]],
  stringsAsFactors = FALSE
)
annual_stats_with_full <- rbind(annual_stats, full_period_row)

absolute_decile <- cut(
  abs(x),
  breaks = unique(stats::quantile(abs(x), probs = seq(0, 1, 0.1), names = FALSE, type = 8)),
  include.lowest = TRUE,
  labels = FALSE
)
if (length(unique(absolute_decile)) != 10L) stop("Absolute-return deciles did not produce ten groups.", call. = FALSE)
magnitude_deciles <- do.call(rbind, lapply(seq_len(10L), function(decile) {
  rows <- which(absolute_decile == decile)
  data.frame(
    prior_absolute_return_decile = decile,
    observations = length(rows),
    mean_prior_absolute_return = mean(abs(x[rows])),
    mean_next_absolute_return = mean(abs(y[rows])),
    median_next_absolute_return = stats::median(abs(y[rows])),
    stringsAsFactors = FALSE
  )
}))

plot_theme <- function() {
  graphics::par(
    family = "sans", bg = "white", fg = "#273548", col.axis = "#526070",
    col.lab = "#273548", mar = c(6.2, 6.8, 5.6, 2.2), mgp = c(3.8, 1.1, 0)
  )
}

scatter_path <- file.path(visual_dir, "tsla_signed_return_dependence_fitted_scatter.png")
grDevices::png(scatter_path, width = 1800, height = 1200, res = 180)
plot_theme()
axis_limit <- max(abs(c(100 * x, 100 * y))) * 1.04
graphics::plot(
  100 * x, 100 * y,
  pch = 16, cex = 0.65,
  col = grDevices::adjustcolor("#4C78A8", alpha.f = 0.38),
  xlim = c(-axis_limit, axis_limit), ylim = c(-axis_limit, axis_limit), asp = 1,
  xlab = "Prior-day log return, r[t-1] (%)",
  ylab = "Next-day log return, r[t] (%)",
  main = "The fitted linear relationship is visually shallow",
  cex.main = 1.55, cex.lab = 1.18, cex.axis = 0.96, bty = "n"
)
graphics::abline(h = 0, v = 0, col = "#8B96A5", lwd = 1)
graphics::abline(a = 100 * stats::coef(fit)[[1L]], b = stats::coef(fit)[[2L]], col = "#E45756", lwd = 3)
graphics::legend(
  "topright", legend = c("Consecutive sessions", "OLS fit"),
  col = c("#4C78A8", "#E45756"), pch = c(16, NA), lty = c(NA, 1), lwd = c(NA, 3),
  bty = "n", cex = 0.95
)
graphics::mtext("Adjusted close-to-close log returns | 1,509 pairs | 2018-2023", side = 3, line = 1.0, cex = 0.95, col = "#667384")
grDevices::dev.off()

direction_path <- file.path(visual_dir, "tsla_direction_transition_probabilities.png")
grDevices::png(direction_path, width = 1800, height = 1050, res = 180)
plot_theme()
positions <- seq_len(nrow(direction_transition))
graphics::plot(
  positions, 100 * direction_transition$up_probability,
  type = "n", xaxt = "n", ylim = range(100 * c(direction_transition$lower_95, direction_transition$upper_95)) + c(-1.2, 1.2),
  xlab = "Prior-session condition", ylab = "Probability next session is up (%)",
  main = "Direction changes little after conditioning on yesterday's sign",
  cex.main = 1.55, cex.lab = 1.18, cex.axis = 0.96, bty = "n"
)
graphics::axis(1, at = positions, labels = direction_transition$condition, tick = FALSE, cex.axis = 0.95)
graphics::segments(
  positions, 100 * direction_transition$lower_95,
  positions, 100 * direction_transition$upper_95,
  col = "#526070", lwd = 2
)
graphics::segments(
  positions - 0.06, 100 * direction_transition$lower_95,
  positions + 0.06, 100 * direction_transition$lower_95,
  col = "#526070", lwd = 2
)
graphics::segments(
  positions - 0.06, 100 * direction_transition$upper_95,
  positions + 0.06, 100 * direction_transition$upper_95,
  col = "#526070", lwd = 2
)
graphics::points(positions, 100 * direction_transition$up_probability, pch = 19, cex = 1.6, col = c("#142033", "#E45756", "#2A9D6F"))
graphics::text(positions, 100 * direction_transition$up_probability, labels = sprintf("%.1f%%", 100 * direction_transition$up_probability), pos = 3, offset = 0.8, cex = 0.95, col = "#273548")
graphics::mtext("Points are observed probabilities; whiskers are 95% circular-block bootstrap intervals", side = 3, line = 1.0, cex = 0.92, col = "#667384")
grDevices::dev.off()

forest_path <- file.path(visual_dir, "tsla_annual_lagged_return_slope_forest.png")
grDevices::png(forest_path, width = 1800, height = 1150, res = 180)
plot_theme()
forest <- annual_stats_with_full[nrow(annual_stats_with_full):1L, , drop = FALSE]
y_position <- seq_len(nrow(forest))
x_range <- range(c(forest$slope_hac_lower_95, forest$slope_hac_upper_95))
x_padding <- 0.08 * diff(x_range)
graphics::plot(
  forest$ols_slope, y_position,
  type = "n", yaxt = "n", xlim = x_range + c(-x_padding, x_padding), ylim = c(0.5, length(y_position) + 0.5),
  xlab = "OLS slope: change in r[t] per unit of r[t-1]", ylab = "",
  main = "The signed relationship is not stable year to year",
  cex.main = 1.55, cex.lab = 1.18, cex.axis = 0.96, bty = "n"
)
graphics::axis(2, at = y_position, labels = forest$period, las = 1, tick = FALSE, cex.axis = 0.98)
graphics::abline(v = 0, col = "#8B96A5", lwd = 1.2, lty = 2)
graphics::segments(forest$slope_hac_lower_95, y_position, forest$slope_hac_upper_95, y_position, col = "#526070", lwd = 2)
point_colors <- ifelse(forest$period == "2018-2023", "#E45756", "#3D8DFF")
point_sizes <- ifelse(forest$period == "2018-2023", 1.55, 1.2)
graphics::points(forest$ols_slope, y_position, pch = 19, cex = point_sizes, col = point_colors)
graphics::mtext("Whiskers are 95% Newey-West/HAC intervals; full-period estimate is red", side = 3, line = 1.0, cex = 0.92, col = "#667384")
grDevices::dev.off()

magnitude_path <- file.path(visual_dir, "tsla_absolute_return_persistence_by_decile.png")
grDevices::png(magnitude_path, width = 1800, height = 1050, res = 180)
plot_theme()
graphics::plot(
  magnitude_deciles$prior_absolute_return_decile,
  100 * magnitude_deciles$mean_next_absolute_return,
  type = "o", pch = 19, lwd = 2.5, cex = 1.15, col = "#3D8DFF",
  xaxt = "n", xlab = "Prior-day absolute-return decile (1 = quietest, 10 = largest)",
  ylab = "Mean next-day absolute log return (%)",
  main = "Magnitude persistence is modest and non-monotonic",
  cex.main = 1.55, cex.lab = 1.18, cex.axis = 0.96, bty = "n"
)
graphics::axis(1, at = seq_len(10L), labels = seq_len(10L), cex.axis = 0.95)
graphics::grid(nx = NA, ny = NULL, col = grDevices::adjustcolor("#8B96A5", alpha.f = 0.25), lty = 1)
graphics::lines(
  magnitude_deciles$prior_absolute_return_decile,
  100 * magnitude_deciles$mean_next_absolute_return,
  type = "o", pch = 19, lwd = 2.5, cex = 1.15, col = "#3D8DFF"
)
graphics::mtext("Equal-count bins describe magnitude persistence; signed direction is ignored", side = 3, line = 1.0, cex = 0.92, col = "#667384")
grDevices::dev.off()

run_spec <- data.frame(
  field = c(
    "symbol", "provider", "bars", "return_definition", "primary_question", "primary_statistic",
    "diagnostics", "query_start", "analysis_start", "analysis_end", "as_of_timestamp", "refresh",
    "bootstrap_method", "bootstrap_replicates", "bootstrap_block_length", "bootstrap_seed",
    "hac_lag_rule", "winsor_sensitivity", "horizon_search", "trading_policy", "post_2023_data"
  ),
  value = c(
    symbol, "Alpaca SIP", "adjusted daily OHLCV",
    "log(adjusted_close_t / adjusted_close_t_minus_1)",
    "linear signed dependence between r_t_minus_1 and r_t",
    "Pearson correlation / equivalent OLS slope",
    "Spearman; direction transitions; absolute-return persistence; 1/99 winsor sensitivity; annual HAC slopes",
    as.character(query_start), as.character(analysis_start), as.character(analysis_end),
    format(as_of_timestamp, "%Y-%m-%d %H:%M:%S %Z"), as.character(refresh),
    "circular moving-block bootstrap over consecutive-pair rows", as.character(bootstrap_replicates),
    as.character(bootstrap_block_length), as.character(bootstrap_seed),
    "floor(4*(n/100)^(2/9)) with Bartlett weights", "1st/99th percentile winsorization",
    "none", "none", "not queried"
  ),
  stringsAsFactors = FALSE
)

utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE, na = "")
utils::write.csv(pair_checks, file.path(output_dir, "pair_checks.csv"), row.names = FALSE, na = "")
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE, na = "")
utils::write.csv(pairs, file.path(output_dir, "tsla_consecutive_daily_return_pairs.csv"), row.names = FALSE, na = "")
utils::write.csv(primary_stats, file.path(output_dir, "primary_statistics.csv"), row.names = FALSE, na = "")
utils::write.csv(bootstrap_intervals, file.path(output_dir, "block_bootstrap_intervals.csv"), row.names = FALSE, na = "")
utils::write.csv(direction_transition, file.path(output_dir, "direction_transition_probabilities.csv"), row.names = FALSE, na = "")
utils::write.csv(direction_difference, file.path(output_dir, "direction_transition_difference.csv"), row.names = FALSE, na = "")
utils::write.csv(outlier_sensitivity, file.path(output_dir, "outlier_sensitivity.csv"), row.names = FALSE, na = "")
utils::write.csv(annual_stats_with_full, file.path(output_dir, "annual_stability.csv"), row.names = FALSE, na = "")
utils::write.csv(magnitude_deciles, file.path(output_dir, "absolute_return_deciles.csv"), row.names = FALSE, na = "")

report_lines <- c(
  "# TSLA Lagged Daily Return Dependence Statistics",
  "",
  "This packet quantifies the previously rendered t-1 versus t scatter without",
  "searching lags, selecting a model, opening a trading rule, or reading post-2023 data.",
  "",
  paste0("- Pairs: `", n, "`"),
  paste0("- Pearson correlation: `", sprintf("%.6f", observed_metrics[["pearson"]]), "`"),
  paste0("- OLS slope: `", sprintf("%.6f", observed_metrics[["slope"]]), "`"),
  paste0("- OLS R-squared: `", sprintf("%.6f", observed_metrics[["r_squared"]]), "`"),
  paste0("- Spearman correlation: `", sprintf("%.6f", observed_metrics[["spearman"]]), "`"),
  paste0("- Direction probability difference: `", sprintf("%.4f", observed_metrics[["direction_difference"]]), "`"),
  paste0("- Absolute-return Pearson correlation: `", sprintf("%.6f", observed_metrics[["absolute_pearson"]]), "`"),
  "- Primary uncertainty: 95% circular-block bootstrap interval",
  paste0("- HAC slope lag: `", hac_lag, "`"),
  "- Statistical role: Pearson/OLS is primary; every other measure is diagnostic",
  "",
  "## Artifacts",
  "",
  "- `visuals/tsla_signed_return_dependence_fitted_scatter.png`",
  "- `visuals/tsla_direction_transition_probabilities.png`",
  "- `visuals/tsla_annual_lagged_return_slope_forest.png`",
  "- `visuals/tsla_absolute_return_persistence_by_decile.png`",
  "- `primary_statistics.csv`",
  "- `block_bootstrap_intervals.csv`",
  "- `direction_transition_probabilities.csv`",
  "- `direction_transition_difference.csv`",
  "- `outlier_sensitivity.csv`",
  "- `annual_stability.csv`"
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

message("TSLA lagged-return dependence measurement complete")
message("Pairs: ", n)
message("Pearson: ", sprintf("%.6f", observed_metrics[["pearson"]]))
message("Absolute-return Pearson: ", sprintf("%.6f", observed_metrics[["absolute_pearson"]]))
message("Output: ", output_dir)
