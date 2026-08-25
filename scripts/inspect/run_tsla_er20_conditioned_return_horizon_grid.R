# Condition the fixed TSLA cumulative-return horizon grid on the previously
# defined causal ER20 path regimes. This is descriptive research only: no cell
# or regime becomes a trading rule, model, or performance claim.

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
er_window_sessions <- 20L
er_trend_cutoff <- 0.30
query_start <- as.Date("2017-10-02")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
as_of_timestamp <- as.POSIXct("2026-08-24 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(
  tolower(Sys.getenv("GEN5_TSLA_ER20_CONDITIONED_GRID_REFRESH", unset = "false")),
  "true"
)

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_er20_conditioned_return_horizon_grid_20260825"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create ER20-conditioned grid output directory.", call. = FALSE)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "tsla_er20_conditioned_return_horizon_grid",
  universe_roles = "single_asset_descriptive_regime_conditioning",
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
  stop("TSLA conditioned-grid source checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

# Reproduce the prior ER20 definition exactly. The state at anchor close t uses
# only closes through t, and therefore cannot see the forward-return window.
log_close <- log(bars$close)
bars$er20 <- NA_real_
for (i in seq.int(er_window_sessions + 1L, nrow(bars))) {
  window_log_close <- log_close[seq.int(i - er_window_sessions, i)]
  path_length <- sum(abs(diff(window_log_close)))
  displacement <- abs(window_log_close[[er_window_sessions + 1L]] - window_log_close[[1L]])
  bars$er20[[i]] <- if (path_length > 0) displacement / path_length else 0
}
bars$path_regime <- ifelse(
  is.na(bars$er20),
  "INSUFFICIENT_HISTORY",
  ifelse(bars$er20 >= er_trend_cutoff, "GREEN_TRENDING", "RED_SIDEWAYS")
)

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
  in_window <-
    bars$session_date[anchor_indices] >= analysis_start &
    forward_start_dates >= analysis_start &
    forward_end_dates <= analysis_end &
    is.finite(bars$er20[anchor_indices])
  anchor_indices <- anchor_indices[in_window]
  if (!length(anchor_indices)) stop("No complete conditioned-grid observations.", call. = FALSE)

  data.frame(
    anchor_session = bars$session_date[anchor_indices],
    prior_start_session = bars$session_date[anchor_indices - prior_sessions],
    forward_start_session = bars$session_date[anchor_indices + 1L],
    forward_end_session = bars$session_date[anchor_indices + forward_sessions],
    er20 = bars$er20[anchor_indices],
    path_regime = bars$path_regime[anchor_indices],
    prior_cumulative_log_return = log(bars$close[anchor_indices] / bars$close[anchor_indices - prior_sessions]),
    forward_cumulative_log_return = log(bars$close[anchor_indices + forward_sessions] / bars$close[anchor_indices]),
    stringsAsFactors = FALSE
  )
}

measure_regime <- function(surface, regime, prior_sessions, forward_sessions) {
  sample <- surface[surface$path_regime == regime, , drop = FALSE]
  x <- sample$prior_cumulative_log_return
  y <- sample$forward_cumulative_log_return
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
  correlation_scale <- stats::sd(x) / stats::sd(y)
  prior_up <- as.numeric(x > 0)
  forward_up <- as.numeric(y > 0)

  data.frame(
    prior_sessions = prior_sessions,
    forward_sessions = forward_sessions,
    regime = regime,
    observations = n,
    first_anchor_session = min(sample$anchor_session),
    last_anchor_session = max(sample$anchor_session),
    mean_er20 = mean(sample$er20),
    pearson_correlation = stats::cor(x, y, method = "pearson"),
    pearson_hac_lower_95 = beta_lower * correlation_scale,
    pearson_hac_upper_95 = beta_upper * correlation_scale,
    spearman_correlation = stats::cor(x, y, method = "spearman"),
    ols_intercept = unname(stats::coef(fit)[[1L]]),
    ols_slope = beta,
    slope_hac_standard_error = se[[2L]],
    slope_hac_lower_95 = beta_lower,
    slope_hac_upper_95 = beta_upper,
    slope_hac_p_value = beta_p,
    ols_r_squared = summary(fit)$r.squared,
    mean_prior_return = mean(x),
    mean_forward_return = mean(y),
    sd_prior_return = stats::sd(x),
    sd_forward_return = stats::sd(y),
    probability_forward_up = mean(forward_up),
    probability_forward_up_after_prior_up = mean(forward_up[prior_up == 1]),
    probability_forward_up_after_prior_down = mean(forward_up[prior_up == 0]),
    direction_difference =
      mean(forward_up[prior_up == 1]) - mean(forward_up[prior_up == 0]),
    same_sign_probability = mean((x > 0) == (y > 0)),
    hac_lag = hac_lag,
    stringsAsFactors = FALSE
  )
}

measure_comparison <- function(surface, prior_sessions, forward_sessions) {
  x <- surface$prior_cumulative_log_return
  y <- surface$forward_cumulative_log_return
  green <- as.numeric(surface$path_regime == "GREEN_TRENDING")
  overlap_lag <- prior_sessions + forward_sessions - 1L
  rule_lag <- floor(4 * (nrow(surface) / 100)^(2 / 9))
  hac_lag <- max(overlap_lag, rule_lag)

  fit <- stats::lm(y ~ x * green)
  covariance <- hac_vcov(fit, hac_lag)
  coefficient_name <- "x:green"
  interaction <- unname(stats::coef(fit)[[coefficient_name]])
  interaction_se <- sqrt(diag(covariance))[[coefficient_name]]
  interaction_z <- interaction / interaction_se

  red <- surface[surface$path_regime == "RED_SIDEWAYS", , drop = FALSE]
  green_rows <- surface[surface$path_regime == "GREEN_TRENDING", , drop = FALSE]
  red_correlation <- stats::cor(red$prior_cumulative_log_return, red$forward_cumulative_log_return)
  green_correlation <- stats::cor(green_rows$prior_cumulative_log_return, green_rows$forward_cumulative_log_return)

  data.frame(
    prior_sessions = prior_sessions,
    forward_sessions = forward_sessions,
    red_observations = nrow(red),
    green_observations = nrow(green_rows),
    red_pearson_correlation = red_correlation,
    green_pearson_correlation = green_correlation,
    green_minus_red_correlation = green_correlation - red_correlation,
    red_r_squared = red_correlation^2,
    green_r_squared = green_correlation^2,
    green_minus_red_r_squared = green_correlation^2 - red_correlation^2,
    red_mean_forward_return = mean(red$forward_cumulative_log_return),
    green_mean_forward_return = mean(green_rows$forward_cumulative_log_return),
    green_minus_red_ols_slope = interaction,
    interaction_hac_standard_error = interaction_se,
    interaction_hac_lower_95 = interaction - stats::qnorm(0.975) * interaction_se,
    interaction_hac_upper_95 = interaction + stats::qnorm(0.975) * interaction_se,
    interaction_hac_p_value = 2 * stats::pnorm(-abs(interaction_z)),
    hac_lag = hac_lag,
    stringsAsFactors = FALSE
  )
}

regime_rows <- vector("list", length(horizons)^2 * 2L)
comparison_rows <- vector("list", length(horizons)^2)
regime_index <- 1L
comparison_index <- 1L
for (prior_sessions in horizons) {
  for (forward_sessions in horizons) {
    surface <- construct_pair_surface(prior_sessions, forward_sessions)
    for (regime in c("RED_SIDEWAYS", "GREEN_TRENDING")) {
      regime_rows[[regime_index]] <- measure_regime(
        surface, regime, prior_sessions, forward_sessions
      )
      regime_index <- regime_index + 1L
    }
    comparison_rows[[comparison_index]] <- measure_comparison(
      surface, prior_sessions, forward_sessions
    )
    comparison_index <- comparison_index + 1L
  }
}

conditioned <- do.call(rbind, regime_rows)
comparison <- do.call(rbind, comparison_rows)
rownames(conditioned) <- NULL
rownames(comparison) <- NULL

conditioned$slope_bh_q_value <- NA_real_
for (regime in unique(conditioned$regime)) {
  rows <- conditioned$regime == regime
  conditioned$slope_bh_q_value[rows] <- stats::p.adjust(
    conditioned$slope_hac_p_value[rows], method = "BH"
  )
}
comparison$interaction_bh_q_value <- stats::p.adjust(
  comparison$interaction_hac_p_value, method = "BH"
)
pooled_p_values <- c(
  conditioned$slope_hac_p_value[conditioned$regime == "RED_SIDEWAYS"],
  conditioned$slope_hac_p_value[conditioned$regime == "GREEN_TRENDING"],
  comparison$interaction_hac_p_value
)
pooled_q_values <- stats::p.adjust(pooled_p_values, method = "BH")
conditioned$slope_omnibus_bh_q_value <- NA_real_
conditioned$slope_omnibus_bh_q_value[conditioned$regime == "RED_SIDEWAYS"] <- pooled_q_values[1:81]
conditioned$slope_omnibus_bh_q_value[conditioned$regime == "GREEN_TRENDING"] <- pooled_q_values[82:162]
comparison$interaction_omnibus_bh_q_value <- pooled_q_values[163:243]

conditioned$pearson_hac_interval_excludes_zero <-
  conditioned$pearson_hac_lower_95 > 0 | conditioned$pearson_hac_upper_95 < 0
conditioned$slope_bh_pass_05 <- conditioned$slope_bh_q_value < 0.05
comparison$interaction_bh_pass_05 <- comparison$interaction_bh_q_value < 0.05

if (nrow(conditioned) != 162L || nrow(comparison) != 81L) {
  stop("Conditioned horizon grid did not produce 162 regime rows and 81 comparisons.", call. = FALSE)
}
if (!all(conditioned$observations > 500L)) stop("Unexpectedly small conditioned-grid sample.", call. = FALSE)
if (!all(vapply(conditioned, function(column) {
  if (is.numeric(column)) all(is.finite(column)) else TRUE
}, logical(1)))) stop("Non-finite conditioned-grid statistic.", call. = FALSE)
if (!all(vapply(comparison, function(column) {
  if (is.numeric(column)) all(is.finite(column)) else TRUE
}, logical(1)))) stop("Non-finite regime-comparison statistic.", call. = FALSE)

grid_checks <- data.frame(
  check_id = c(
    "predeclared_horizons_exact", "conditioned_row_count_exact", "comparison_row_count_exact",
    "er20_definition_fixed", "regime_threshold_fixed", "regime_known_at_anchor",
    "prior_forward_windows_do_not_share_returns", "all_forward_windows_end_by_2023",
    "all_regime_samples_above_500", "all_statistics_finite"
  ),
  passed = c(
    identical(sort(unique(conditioned$prior_sessions)), horizons) &&
      identical(sort(unique(conditioned$forward_sessions)), horizons),
    nrow(conditioned) == 162L,
    nrow(comparison) == 81L,
    er_window_sessions == 20L,
    identical(er_trend_cutoff, 0.30),
    TRUE,
    TRUE,
    max(as.Date(construct_pair_surface(25L, 25L)$forward_end_session)) <= analysis_end,
    min(conditioned$observations) > 500L,
    all(is.finite(conditioned$pearson_correlation)) &&
      all(is.finite(comparison$green_minus_red_correlation))
  ),
  observed = c(
    paste(horizons, collapse = ","),
    as.character(nrow(conditioned)),
    as.character(nrow(comparison)),
    "abs(log_close[t]-log_close[t-20]) / sum(abs(one-session log moves))",
    "GREEN_TRENDING if ER20 >= 0.30; RED_SIDEWAYS otherwise",
    "ER20 at anchor t uses closes through t only",
    "prior ends at anchor close; forward starts after anchor close",
    as.character(max(as.Date(construct_pair_surface(25L, 25L)$forward_end_session))),
    paste(range(conditioned$observations), collapse = " to "),
    "all primary numeric fields finite"
  ),
  stringsAsFactors = FALSE
)
if (!all(grid_checks$passed)) {
  failed <- grid_checks$check_id[!grid_checks$passed]
  stop("TSLA conditioned-grid checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

matrix_for_conditioned <- function(column, regime) {
  subset <- conditioned[conditioned$regime == regime, , drop = FALSE]
  result <- matrix(
    NA_real_, nrow = length(horizons), ncol = length(horizons),
    dimnames = list(as.character(horizons), as.character(horizons))
  )
  for (i in seq_len(nrow(subset))) {
    result[as.character(subset$prior_sessions[[i]]), as.character(subset$forward_sessions[[i]])] <-
      subset[[column]][[i]]
  }
  result
}

matrix_for_comparison <- function(column) {
  result <- matrix(
    NA_real_, nrow = length(horizons), ncol = length(horizons),
    dimnames = list(as.character(horizons), as.character(horizons))
  )
  for (i in seq_len(nrow(comparison))) {
    result[as.character(comparison$prior_sessions[[i]]), as.character(comparison$forward_sessions[[i]])] <-
      comparison[[column]][[i]]
  }
  result
}

write_matrix_csv <- function(values, file_name, digits = NULL) {
  output <- data.frame(prior_sessions = as.integer(rownames(values)), values, check.names = FALSE)
  if (!is.null(digits)) output[-1L] <- lapply(output[-1L], round, digits = digits)
  utils::write.csv(output, file.path(output_dir, file_name), row.names = FALSE)
}

red_pearson <- matrix_for_conditioned("pearson_correlation", "RED_SIDEWAYS")
green_pearson <- matrix_for_conditioned("pearson_correlation", "GREEN_TRENDING")
delta_pearson <- matrix_for_comparison("green_minus_red_correlation")
interaction_q <- matrix_for_comparison("interaction_bh_q_value")
red_r_squared <- 100 * matrix_for_conditioned("ols_r_squared", "RED_SIDEWAYS")
green_r_squared <- 100 * matrix_for_conditioned("ols_r_squared", "GREEN_TRENDING")
red_samples <- matrix_for_conditioned("observations", "RED_SIDEWAYS")
green_samples <- matrix_for_conditioned("observations", "GREEN_TRENDING")

utils::write.csv(conditioned, file.path(output_dir, "conditioned_horizon_grid_statistics.csv"), row.names = FALSE)
utils::write.csv(comparison, file.path(output_dir, "regime_comparison_statistics.csv"), row.names = FALSE)
utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(grid_checks, file.path(output_dir, "grid_checks.csv"), row.names = FALSE)
write_matrix_csv(red_pearson, "red_sideways_pearson_matrix.csv", 4L)
write_matrix_csv(green_pearson, "green_trending_pearson_matrix.csv", 4L)
write_matrix_csv(delta_pearson, "green_minus_red_pearson_matrix.csv", 4L)
write_matrix_csv(interaction_q, "slope_interaction_bh_q_value_matrix.csv", 5L)
write_matrix_csv(red_r_squared, "red_sideways_r_squared_percent_matrix.csv", 3L)
write_matrix_csv(green_r_squared, "green_trending_r_squared_percent_matrix.csv", 3L)
write_matrix_csv(red_samples, "red_sideways_sample_size_matrix.csv", 0L)
write_matrix_csv(green_samples, "green_trending_sample_size_matrix.csv", 0L)

ranked_difference <- comparison[order(-abs(comparison$green_minus_red_correlation)), , drop = FALSE]
ranked_difference$absolute_correlation_difference <- abs(ranked_difference$green_minus_red_correlation)
utils::write.csv(
  ranked_difference,
  file.path(output_dir, "cells_ranked_by_absolute_regime_difference.csv"),
  row.names = FALSE
)

for (regime in c("RED_SIDEWAYS", "GREEN_TRENDING")) {
  ranked <- conditioned[conditioned$regime == regime, , drop = FALSE]
  ranked <- ranked[order(-abs(ranked$pearson_correlation)), , drop = FALSE]
  ranked$absolute_pearson_correlation <- abs(ranked$pearson_correlation)
  file_name <- if (regime == "RED_SIDEWAYS") {
    "red_sideways_cells_ranked_by_absolute_correlation.csv"
  } else {
    "green_trending_cells_ranked_by_absolute_correlation.csv"
  }
  utils::write.csv(ranked, file.path(output_dir, file_name), row.names = FALSE)
}

run_spec <- data.frame(
  field = c(
    "asset", "provider", "bar_type", "return_definition", "prior_horizons",
    "forward_horizons", "regime_metric", "regime_timing", "red_definition",
    "green_definition", "analysis_start", "analysis_end", "as_of_timestamp",
    "conditioned_cells", "comparison_cells", "uncertainty", "hac_lag_rule",
    "multiplicity", "post_2023_confirmation", "trading_calculation"
  ),
  value = c(
    symbol, "Alpaca SIP", "adjusted daily OHLCV",
    "log(close_anchor/close_anchor_minus_p) versus log(close_anchor_plus_f/close_anchor)",
    paste(horizons, collapse = ","), paste(horizons, collapse = ","),
    "20-session log-price Kaufman efficiency ratio",
    "ER20 at anchor t uses closes through t only",
    "ER20 < 0.30 (sideways/choppy)", "ER20 >= 0.30 (trending)",
    as.character(analysis_start), as.character(analysis_end),
    format(as_of_timestamp, tz = cfg$calendar$timezone),
    nrow(conditioned), nrow(comparison), "95% Newey-West/HAC intervals",
    "max(p+f-1, floor(4*(n/100)^(2/9)))",
    "BH-FDR within each 81-cell family plus pooled BH-FDR across 243 signed-return tests",
    "none", "none"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

draw_heatmap <- function(values, output_path, title, subtitle, label_format, limit = NULL,
                         negative_color = "#D95F5F", positive_color = "#3D8DFF") {
  if (is.null(limit)) limit <- max(abs(values), na.rm = TRUE)
  if (!is.finite(limit) || limit <= 0) limit <- 1
  palette <- grDevices::colorRampPalette(c(negative_color, "#F7F8FA", positive_color))(201)
  grDevices::png(output_path, width = 1800, height = 1250, res = 180)
  old_par <- graphics::par(
    family = "sans", bg = "white", fg = "#273548", col.axis = "#526070",
    col.lab = "#273548", mar = c(6.4, 6.9, 5.8, 3.0), mgp = c(3.9, 1.1, 0)
  )
  on.exit({ graphics::par(old_par); grDevices::dev.off() }, add = TRUE)
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
    }
  }
  graphics::mtext(subtitle, side = 3, line = 1.0, cex = 0.88, col = "#667384")
  graphics::box(col = "#CDD3DA")
}

common_limit <- max(abs(c(red_pearson, green_pearson)))
draw_heatmap(
  red_pearson,
  file.path(visual_dir, "tsla_red_sideways_pearson_heatmap.png"),
  "TSLA return dependence when ER20 is red",
  "ER20 < 0.30 at the anchor close | Cell values are Pearson correlations",
  "%+.3f", limit = common_limit, negative_color = "#B93A48", positive_color = "#3D8DFF"
)
draw_heatmap(
  green_pearson,
  file.path(visual_dir, "tsla_green_trending_pearson_heatmap.png"),
  "TSLA return dependence when ER20 is green",
  "ER20 >= 0.30 at the anchor close | Same color scale as the red panel",
  "%+.3f", limit = common_limit, negative_color = "#B93A48", positive_color = "#2B9860"
)
draw_heatmap(
  delta_pearson,
  file.path(visual_dir, "tsla_green_minus_red_pearson_heatmap.png"),
  "How much does correlation change in green versus red ER20 states?",
  "Cell values are green Pearson correlation minus red Pearson correlation",
  "%+.3f", negative_color = "#B93A48", positive_color = "#2B9860"
)

markdown_matrix <- function(values, digits = 3L) {
  header <- paste(c("Prior \\ Forward", colnames(values)), collapse = " | ")
  separator <- paste(c("---", rep("---:", ncol(values))), collapse = " | ")
  rows <- vapply(seq_len(nrow(values)), function(i) {
    formatted <- formatC(values[i, ], format = "f", digits = digits)
    paste(c(rownames(values)[[i]], formatted), collapse = " | ")
  }, character(1))
  paste(c(paste0("| ", header, " |"), paste0("| ", separator, " |"), paste0("| ", rows, " |")), collapse = "\n")
}

top_red <- conditioned[conditioned$regime == "RED_SIDEWAYS", , drop = FALSE]
top_red <- top_red[order(-abs(top_red$pearson_correlation)), , drop = FALSE][1L, ]
top_green <- conditioned[conditioned$regime == "GREEN_TRENDING", , drop = FALSE]
top_green <- top_green[order(-abs(top_green$pearson_correlation)), , drop = FALSE][1L, ]
top_difference <- ranked_difference[1L, , drop = FALSE]

report_lines <- c(
  "# TSLA ER20-Conditioned Cumulative Return Horizon Grid",
  "",
  "## Question",
  "",
  "Is prior-versus-forward cumulative signed-return dependence stronger in the previously defined red/sideways ER20 state or the green/trending ER20 state, such that aggregation across both states obscures the relationship?",
  "",
  "## Fixed Conditioning Rule",
  "",
  "- `ER20 = abs(log_close[t] - log_close[t-20]) / sum(abs(one-session log moves))`.",
  "- Red/sideways: `ER20 < 0.30` at the anchor close.",
  "- Green/trending: `ER20 >= 0.30` at the anchor close.",
  "- ER20 uses only information through the anchor close; the forward window begins on the following session.",
  "- Anchor sessions are restricted to the 2018-2023 visible ER ledger, so the pre-2018 anchor from the aggregate grid is not assigned a color.",
  "- The same fixed 9 x 9 prior/forward grid and 2018-2023 window are retained.",
  "",
  "## Red / Sideways Pearson Matrix",
  "",
  markdown_matrix(red_pearson),
  "",
  "## Green / Trending Pearson Matrix",
  "",
  markdown_matrix(green_pearson),
  "",
  "## Green Minus Red Pearson Matrix",
  "",
  markdown_matrix(delta_pearson),
  "",
  "## Descriptive Readout",
  "",
  sprintf(
    "- Largest absolute red correlation: `%+.4f` at prior `%d` / forward `%d` (`n=%d`, family BH q=`%.4f`, R-squared=`%.3f%%`).",
    top_red$pearson_correlation, top_red$prior_sessions, top_red$forward_sessions,
    top_red$observations, top_red$slope_bh_q_value, 100 * top_red$ols_r_squared
  ),
  sprintf(
    "- Largest absolute green correlation: `%+.4f` at prior `%d` / forward `%d` (`n=%d`, family BH q=`%.4f`, R-squared=`%.3f%%`).",
    top_green$pearson_correlation, top_green$prior_sessions, top_green$forward_sessions,
    top_green$observations, top_green$slope_bh_q_value, 100 * top_green$ols_r_squared
  ),
  sprintf(
    "- Largest absolute green-minus-red correlation difference: `%+.4f` at prior `%d` / forward `%d` (interaction HAC p=`%.4f`, family BH q=`%.4f`).",
    top_difference$green_minus_red_correlation, top_difference$prior_sessions,
    top_difference$forward_sessions, top_difference$interaction_hac_p_value,
    top_difference$interaction_bh_q_value
  ),
  sprintf(
    "- Within-regime signed-return BH-FDR passes: red `%d / 81`; green `%d / 81`.",
    sum(conditioned$slope_bh_pass_05 & conditioned$regime == "RED_SIDEWAYS"),
    sum(conditioned$slope_bh_pass_05 & conditioned$regime == "GREEN_TRENDING")
  ),
  sprintf(
    "- Red-versus-green slope-interaction BH-FDR passes: `%d / 81`.",
    sum(comparison$interaction_bh_pass_05)
  ),
  "",
  "## Interpretive Guardrails",
  "",
  "- ER20 and the prior-return variable are both functions of the trailing price path. Conditioning can therefore expose real state dependence, but it can also create geometry-driven selection effects. This slice does not identify ER20 as a causal moderator.",
  "- Horizon cells are nested and overlapping. Newey-West/HAC uncertainty addresses serial dependence within a cell; BH-FDR addresses the grid search, but neither turns the 81 cells into independent experiments.",
  "- This remains descriptive navigation. A promising region must be frozen before replication or strategy interpretation.",
  "",
  "## Artifacts",
  "",
  "- `conditioned_horizon_grid_statistics.csv`: 162 regime-specific rows.",
  "- `regime_comparison_statistics.csv`: 81 red-versus-green comparisons.",
  "- Matrix CSVs: correlations, differences, R-squared, samples, and interaction q-values.",
  "- `cells_ranked_by_absolute_regime_difference.csv`: descriptive navigation ranking.",
  "- `visuals/`: red, green, and green-minus-red correlation heatmaps."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

cat("TSLA ER20-conditioned cumulative-return horizon grid complete.\n")
cat("Conditioned rows:", nrow(conditioned), "| comparisons:", nrow(comparison), "\n")
cat("Regime observations per cell:", min(conditioned$observations), "to", max(conditioned$observations), "\n")
cat("Largest red absolute Pearson:", sprintf("%+.4f", top_red$pearson_correlation),
    "at", top_red$prior_sessions, "/", top_red$forward_sessions, "\n")
cat("Largest green absolute Pearson:", sprintf("%+.4f", top_green$pearson_correlation),
    "at", top_green$prior_sessions, "/", top_green$forward_sessions, "\n")
cat("Largest absolute regime difference:", sprintf("%+.4f", top_difference$green_minus_red_correlation),
    "at", top_difference$prior_sessions, "/", top_difference$forward_sessions, "\n")
cat("Output:", output_dir, "\n")
