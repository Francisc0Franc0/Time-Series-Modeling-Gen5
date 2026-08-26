# Compare prior cumulative QQQ and SPY daily log returns with following
# cumulative TSLA daily log returns on the frozen 9 x 9 horizon surface.
# This is descriptive cross-asset navigation only: no cell becomes a model,
# trading rule, or performance claim.

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
target_symbol <- "TSLA"
predictor_symbols <- c("QQQ", "SPY")
symbols <- c(target_symbol, predictor_symbols)
horizons <- c(1L, 2L, 3L, 4L, 5L, 10L, 15L, 20L, 25L)
query_start <- as.Date("2017-10-02")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
as_of_timestamp <- as.POSIXct("2026-08-24 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(
  tolower(Sys.getenv("GEN5_TSLA_QQQ_SPY_PRIOR_RETURN_GRID_REFRESH", unset = "false")),
  "true"
)

output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_qqq_spy_prior_return_horizon_grid_20260825"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create cross-asset horizon-grid output directory.", call. = FALSE)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbols,
  universe_name = "tsla_qqq_spy_prior_return_horizon_grid",
  universe_roles = "cross_asset_descriptive_lead_lag_grid",
  refresh = refresh,
  repo_root = repo_root
)

bars <- query$bars
bars$session_date <- as.Date(bars$session_date)
bars <- bars[bars$symbol %in% symbols, , drop = FALSE]
bars <- bars[order(bars$symbol, bars$session_date), , drop = FALSE]

symbol_checks <- do.call(rbind, lapply(symbols, function(symbol) {
  sample <- bars[bars$symbol == symbol, , drop = FALSE]
  data.frame(
    symbol = symbol,
    rows = nrow(sample),
    unique_sessions = !anyDuplicated(sample$session_date),
    strict_date_order = nrow(sample) > 1L && all(diff(sample$session_date) > 0),
    positive_finite_close = nrow(sample) > 0L && all(is.finite(sample$close) & sample$close > 0),
    adjusted_daily_only = nrow(sample) > 0L && all(sample$adjusted %in% TRUE) && all(sample$timeframe == "1D"),
    warmup_covered = nrow(sample) > 0L && min(sample$session_date) <= query_start,
    analysis_end_covered = nrow(sample) > 0L && max(sample$session_date) >= analysis_end,
    future_rows_absent = nrow(sample) > 0L && max(sample$session_date) <= analysis_end,
    first_session = if (nrow(sample)) as.character(min(sample$session_date)) else NA_character_,
    last_session = if (nrow(sample)) as.character(max(sample$session_date)) else NA_character_,
    stringsAsFactors = FALSE
  )
}))
source_checks <- data.frame(
  check_id = c("exact_symbols", "symbol_contracts_pass", "common_calendar_complete"),
  passed = c(
    identical(sort(unique(as.character(bars$symbol))), sort(symbols)),
    all(unlist(symbol_checks[c(
      "unique_sessions", "strict_date_order", "positive_finite_close",
      "adjusted_daily_only", "warmup_covered", "analysis_end_covered", "future_rows_absent"
    )])),
    FALSE
  ),
  observed = c(
    paste(sort(unique(as.character(bars$symbol))), collapse = ","),
    paste(symbol_checks$symbol, symbol_checks$rows, sep = "=", collapse = ", "),
    "pending alignment"
  ),
  stringsAsFactors = FALSE
)

close_series <- lapply(symbols, function(symbol) {
  sample <- bars[bars$symbol == symbol, c("session_date", "close"), drop = FALSE]
  names(sample)[[2L]] <- paste0(tolower(symbol), "_close")
  sample
})
aligned <- Reduce(function(left, right) merge(left, right, by = "session_date", all = FALSE, sort = TRUE), close_series)
source_checks$passed[source_checks$check_id == "common_calendar_complete"] <-
  nrow(aligned) > 0L && min(aligned$session_date) <= query_start && max(aligned$session_date) >= analysis_end
source_checks$observed[source_checks$check_id == "common_calendar_complete"] <- sprintf(
  "%d common sessions, %s to %s", nrow(aligned), min(aligned$session_date), max(aligned$session_date)
)
if (!all(source_checks$passed)) {
  failed <- source_checks$check_id[!source_checks$passed]
  stop("Cross-asset horizon-grid source checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
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

construct_surface <- function(predictor_symbol, prior_sessions, forward_sessions) {
  predictor_close <- aligned[[paste0(tolower(predictor_symbol), "_close")]]
  target_close <- aligned$tsla_close
  anchor_indices <- seq_len(nrow(aligned))
  usable <- anchor_indices - prior_sessions >= 1L & anchor_indices + forward_sessions <= nrow(aligned)
  anchor_indices <- anchor_indices[usable]
  forward_start_dates <- aligned$session_date[anchor_indices + 1L]
  forward_end_dates <- aligned$session_date[anchor_indices + forward_sessions]
  in_window <- forward_start_dates >= analysis_start & forward_end_dates <= analysis_end
  anchor_indices <- anchor_indices[in_window]
  if (!length(anchor_indices)) stop("No complete cross-asset horizon-grid observations.", call. = FALSE)
  data.frame(
    anchor_session = aligned$session_date[anchor_indices],
    predictor_prior_start_session = aligned$session_date[anchor_indices - prior_sessions],
    target_forward_start_session = aligned$session_date[anchor_indices + 1L],
    target_forward_end_session = aligned$session_date[anchor_indices + forward_sessions],
    predictor_prior_cumulative_log_return = log(
      predictor_close[anchor_indices] / predictor_close[anchor_indices - prior_sessions]
    ),
    target_forward_cumulative_log_return = log(
      target_close[anchor_indices + forward_sessions] / target_close[anchor_indices]
    ),
    stringsAsFactors = FALSE
  )
}

measure_cell <- function(predictor_symbol, prior_sessions, forward_sessions) {
  surface <- construct_surface(predictor_symbol, prior_sessions, forward_sessions)
  x <- surface$predictor_prior_cumulative_log_return
  y <- surface$target_forward_cumulative_log_return
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
  predictor_up <- as.numeric(x > 0)
  target_up <- as.numeric(y > 0)
  direction_fit <- stats::lm(target_up ~ predictor_up)
  direction_covariance <- hac_vcov(direction_fit, hac_lag)
  direction_se <- sqrt(diag(direction_covariance))[[2L]]
  direction_difference <- unname(stats::coef(direction_fit)[[2L]])
  direction_z <- direction_difference / direction_se
  data.frame(
    predictor_symbol = predictor_symbol,
    target_symbol = target_symbol,
    prior_sessions = prior_sessions,
    forward_sessions = forward_sessions,
    observations = n,
    first_target_forward_session = min(surface$target_forward_start_session),
    last_target_forward_end_session = max(surface$target_forward_end_session),
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
    mean_predictor_prior_return = mean(x),
    mean_target_forward_return = mean(y),
    sd_predictor_prior_return = stats::sd(x),
    sd_target_forward_return = stats::sd(y),
    probability_target_forward_up = mean(target_up),
    probability_target_forward_up_after_predictor_up = mean(target_up[predictor_up == 1]),
    probability_target_forward_up_after_predictor_down = mean(target_up[predictor_up == 0]),
    direction_difference = direction_difference,
    direction_hac_lower_95 = direction_difference - stats::qnorm(0.975) * direction_se,
    direction_hac_upper_95 = direction_difference + stats::qnorm(0.975) * direction_se,
    direction_hac_p_value = 2 * stats::pnorm(-abs(direction_z)),
    same_sign_probability = mean((x > 0) == (y > 0)),
    stringsAsFactors = FALSE
  )
}

grid_rows <- vector("list", length(predictor_symbols) * length(horizons)^2)
row_index <- 1L
for (predictor_symbol in predictor_symbols) {
  for (prior_sessions in horizons) {
    for (forward_sessions in horizons) {
      grid_rows[[row_index]] <- measure_cell(predictor_symbol, prior_sessions, forward_sessions)
      row_index <- row_index + 1L
    }
  }
}
grid <- do.call(rbind, grid_rows)
rownames(grid) <- NULL
grid$slope_family_bh_q_value <- ave(
  grid$slope_hac_p_value, grid$predictor_symbol,
  FUN = function(values) stats::p.adjust(values, method = "BH")
)
grid$slope_omnibus_bh_q_value <- stats::p.adjust(grid$slope_hac_p_value, method = "BH")
grid$direction_family_bh_q_value <- ave(
  grid$direction_hac_p_value, grid$predictor_symbol,
  FUN = function(values) stats::p.adjust(values, method = "BH")
)
grid$direction_omnibus_bh_q_value <- stats::p.adjust(grid$direction_hac_p_value, method = "BH")
grid$pearson_hac_interval_excludes_zero <-
  grid$pearson_hac_lower_95 > 0 | grid$pearson_hac_upper_95 < 0
grid$slope_family_bh_pass_05 <- grid$slope_family_bh_q_value < 0.05
grid$slope_omnibus_bh_pass_05 <- grid$slope_omnibus_bh_q_value < 0.05

qqq_grid <- grid[grid$predictor_symbol == "QQQ", , drop = FALSE]
spy_grid <- grid[grid$predictor_symbol == "SPY", , drop = FALSE]
comparison <- merge(
  qqq_grid[c("prior_sessions", "forward_sessions", "pearson_correlation", "ols_r_squared")],
  spy_grid[c("prior_sessions", "forward_sessions", "pearson_correlation", "ols_r_squared")],
  by = c("prior_sessions", "forward_sessions"), suffixes = c("_qqq", "_spy"), sort = TRUE
)
comparison$qqq_minus_spy_pearson <- comparison$pearson_correlation_qqq - comparison$pearson_correlation_spy
comparison$qqq_minus_spy_r_squared_pp <- 100 * (comparison$ols_r_squared_qqq - comparison$ols_r_squared_spy)
comparison$same_sign <- sign(comparison$pearson_correlation_qqq) == sign(comparison$pearson_correlation_spy)

grid_checks <- data.frame(
  check_id = c(
    "predeclared_horizons_exact", "predictor_cell_counts_exact", "one_by_one_samples_exact",
    "prior_ends_at_anchor", "forward_starts_after_anchor", "all_forward_windows_end_by_2023",
    "all_cells_have_large_samples", "all_statistics_finite", "comparison_cells_exact"
  ),
  passed = c(
    identical(sort(unique(grid$prior_sessions)), horizons) &&
      identical(sort(unique(grid$forward_sessions)), horizons),
    identical(as.integer(table(factor(grid$predictor_symbol, levels = predictor_symbols))), c(81L, 81L)),
    all(grid$observations[grid$prior_sessions == 1L & grid$forward_sessions == 1L] == 1509L),
    TRUE, TRUE,
    max(as.Date(grid$last_target_forward_end_session)) <= analysis_end,
    min(grid$observations) > 1400L,
    all(vapply(grid, function(column) if (is.numeric(column)) all(is.finite(column)) else TRUE, logical(1))),
    nrow(comparison) == 81L
  ),
  observed = c(
    paste(horizons, collapse = ","),
    paste(names(table(grid$predictor_symbol)), as.integer(table(grid$predictor_symbol)), sep = "=", collapse = ", "),
    paste(grid$predictor_symbol[grid$prior_sessions == 1L & grid$forward_sessions == 1L],
          grid$observations[grid$prior_sessions == 1L & grid$forward_sessions == 1L], sep = "=", collapse = ", "),
    "predictor prior window ends at anchor close",
    "TSLA forward window begins after anchor close",
    as.character(max(as.Date(grid$last_target_forward_end_session))),
    paste(range(grid$observations), collapse = " to "),
    "all numeric fields finite",
    as.character(nrow(comparison))
  ),
  stringsAsFactors = FALSE
)
if (!all(grid_checks$passed)) {
  failed <- grid_checks$check_id[!grid_checks$passed]
  stop("Cross-asset horizon-grid checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

matrix_for <- function(data, column) {
  result <- matrix(
    NA_real_, nrow = length(horizons), ncol = length(horizons),
    dimnames = list(as.character(horizons), as.character(horizons))
  )
  for (i in seq_len(nrow(data))) {
    result[as.character(data$prior_sessions[[i]]), as.character(data$forward_sessions[[i]])] <- data[[column]][[i]]
  }
  result
}

write_matrix_csv <- function(values, file_name, digits = NULL) {
  output <- data.frame(prior_sessions = as.integer(rownames(values)), values, check.names = FALSE)
  if (!is.null(digits)) output[-1L] <- lapply(output[-1L], round, digits = digits)
  utils::write.csv(output, file.path(output_dir, file_name), row.names = FALSE)
}

qqq_pearson <- matrix_for(qqq_grid, "pearson_correlation")
spy_pearson <- matrix_for(spy_grid, "pearson_correlation")
qqq_q <- matrix_for(qqq_grid, "slope_family_bh_q_value")
spy_q <- matrix_for(spy_grid, "slope_family_bh_q_value")
difference_matrix <- matrix_for(comparison, "qqq_minus_spy_pearson")
utils::write.csv(grid, file.path(output_dir, "cross_asset_horizon_grid_statistics.csv"), row.names = FALSE)
utils::write.csv(comparison, file.path(output_dir, "qqq_vs_spy_cell_comparison.csv"), row.names = FALSE)
utils::write.csv(symbol_checks, file.path(output_dir, "symbol_checks.csv"), row.names = FALSE)
utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(grid_checks, file.path(output_dir, "grid_checks.csv"), row.names = FALSE)
write_matrix_csv(qqq_pearson, "qqq_prior_return_pearson_matrix.csv", 4L)
write_matrix_csv(spy_pearson, "spy_prior_return_pearson_matrix.csv", 4L)
write_matrix_csv(qqq_q, "qqq_prior_return_family_bh_q_matrix.csv", 5L)
write_matrix_csv(spy_q, "spy_prior_return_family_bh_q_matrix.csv", 5L)
write_matrix_csv(difference_matrix, "qqq_minus_spy_pearson_difference_matrix.csv", 4L)

ranked <- grid[order(-abs(grid$pearson_correlation)), , drop = FALSE]
ranked$absolute_pearson_correlation <- abs(ranked$pearson_correlation)
utils::write.csv(ranked, file.path(output_dir, "cells_ranked_by_absolute_correlation.csv"), row.names = FALSE)

map_summary <- do.call(rbind, lapply(predictor_symbols, function(predictor_symbol) {
  sample <- grid[grid$predictor_symbol == predictor_symbol, , drop = FALSE]
  max_row <- sample[which.max(abs(sample$pearson_correlation)), , drop = FALSE]
  data.frame(
    predictor_symbol = predictor_symbol,
    mean_pearson = mean(sample$pearson_correlation),
    positive_cells = sum(sample$pearson_correlation > 0),
    negative_cells = sum(sample$pearson_correlation < 0),
    maximum_absolute_pearson = max(abs(sample$pearson_correlation)),
    maximum_cell_pearson = max_row$pearson_correlation,
    maximum_cell_prior_sessions = max_row$prior_sessions,
    maximum_cell_forward_sessions = max_row$forward_sessions,
    family_bh_passes = sum(sample$slope_family_bh_pass_05),
    omnibus_bh_passes = sum(sample$slope_omnibus_bh_pass_05),
    stringsAsFactors = FALSE
  )
}))
utils::write.csv(map_summary, file.path(output_dir, "predictor_map_summary.csv"), row.names = FALSE)

own_grid_path <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_cumulative_return_horizon_grid_20260825", "horizon_grid_statistics.csv"
)
if (!file.exists(own_grid_path)) {
  stop("Frozen TSLA-own prior-return comparison packet is missing.", call. = FALSE)
}
own_grid <- utils::read.csv(own_grid_path, stringsAsFactors = FALSE)
own_grid <- own_grid[c("prior_sessions", "forward_sessions", "pearson_correlation")]
names(own_grid)[names(own_grid) == "pearson_correlation"] <- "tsla_own_pearson"
own_pearson <- matrix_for(own_grid, "tsla_own_pearson")
three_way <- merge(
  merge(
    own_grid,
    qqq_grid[c("prior_sessions", "forward_sessions", "pearson_correlation")],
    by = c("prior_sessions", "forward_sessions"), sort = TRUE
  ),
  spy_grid[c("prior_sessions", "forward_sessions", "pearson_correlation")],
  by = c("prior_sessions", "forward_sessions"), sort = TRUE,
  suffixes = c("_qqq", "_spy")
)
names(three_way)[names(three_way) == "pearson_correlation_qqq"] <- "qqq_prior_pearson"
names(three_way)[names(three_way) == "pearson_correlation_spy"] <- "spy_prior_pearson"
if (nrow(three_way) != 81L) stop("TSLA-own/QQQ/SPY maps did not align on all 81 cells.", call. = FALSE)
own_values <- three_way$tsla_own_pearson
authorities <- list(
  TSLA_OWN = own_values,
  QQQ = three_way$qqq_prior_pearson,
  SPY = three_way$spy_prior_pearson
)
three_way_summary <- do.call(rbind, lapply(names(authorities), function(authority) {
  values <- authorities[[authority]]
  max_index <- which.max(abs(values))
  data.frame(
    prior_return_authority = authority,
    mean_pearson = mean(values),
    positive_cells = sum(values > 0),
    negative_cells = sum(values < 0),
    maximum_absolute_pearson = max(abs(values)),
    maximum_cell_pearson = values[[max_index]],
    maximum_cell_prior_sessions = three_way$prior_sessions[[max_index]],
    maximum_cell_forward_sessions = three_way$forward_sessions[[max_index]],
    cellwise_map_correlation_vs_tsla_own = stats::cor(own_values, values),
    sign_agreement_vs_tsla_own = sum(sign(own_values) == sign(values)),
    stringsAsFactors = FALSE
  )
}))
utils::write.csv(three_way, file.path(output_dir, "tsla_own_qqq_spy_cell_comparison.csv"), row.names = FALSE)
utils::write.csv(three_way_summary, file.path(output_dir, "tsla_own_qqq_spy_map_summary.csv"), row.names = FALSE)

run_spec <- data.frame(
  field = c(
    "target_asset", "predictor_assets", "provider", "bar_type", "predictor_return_definition",
    "target_return_definition", "prior_horizons", "forward_horizons", "analysis_start", "analysis_end",
    "as_of_timestamp", "cell_count", "primary_measure", "uncertainty", "hac_lag_rule",
    "multiplicity", "direct_qqq_spy_difference_test", "post_2023_confirmation", "trading_calculation"
  ),
  value = c(
    target_symbol, paste(predictor_symbols, collapse = ","), "Alpaca SIP", "adjusted daily OHLCV",
    "log(predictor_close_anchor/predictor_close_anchor_minus_p)",
    "log(TSLA_close_anchor_plus_f/TSLA_close_anchor)",
    paste(horizons, collapse = ","), paste(horizons, collapse = ","),
    as.character(analysis_start), as.character(analysis_end), format(as_of_timestamp, tz = cfg$calendar$timezone),
    nrow(grid), "Pearson correlation / OLS slope", "95% Newey-West/HAC intervals",
    "max(p+f-1, floor(4*(n/100)^(2/9)))",
    "BH-FDR within each 81-cell predictor family and across all 162 cells",
    "none; QQQ-minus-SPY map is descriptive", "none", "none"
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
                         outline = NULL, width = 1680, height = 1320) {
  if (is.null(limit)) limit <- max(abs(values), na.rm = TRUE)
  if (!is.finite(limit) || limit <= 0) limit <- 1
  palette <- grDevices::colorRampPalette(c("#D95F5F", "#F7F8FA", "#3D8DFF"))(201)
  grDevices::png(output_path, width = width, height = height, res = 180)
  plot_theme()
  graphics::image(
    x = seq_along(horizons), y = seq_along(horizons), z = t(values),
    col = palette, zlim = c(-limit, limit), axes = FALSE,
    xlab = "Following TSLA sessions in cumulative log return",
    ylab = "Prior predictor sessions in cumulative log return",
    main = title, cex.main = 1.42, cex.lab = 1.08
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
  graphics::mtext(subtitle, side = 3, line = 1.0, cex = 0.86, col = "#667384")
  graphics::box(col = "#CDD3DA")
  grDevices::dev.off()
}

shared_limit <- max(abs(c(qqq_pearson, spy_pearson)))
draw_heatmap(
  qqq_pearson,
  file.path(visual_dir, "qqq_prior_return_vs_tsla_future_pearson_heatmap.png"),
  "Prior QQQ return versus following TSLA return",
  "Pearson correlations | Shared QQQ/SPY color scale | Outlines mark within-QQQ BH q < 0.05",
  "%+.3f", limit = shared_limit, outline = qqq_q < 0.05
)
draw_heatmap(
  spy_pearson,
  file.path(visual_dir, "spy_prior_return_vs_tsla_future_pearson_heatmap.png"),
  "Prior SPY return versus following TSLA return",
  "Pearson correlations | Shared QQQ/SPY color scale | Outlines mark within-SPY BH q < 0.05",
  "%+.3f", limit = shared_limit, outline = spy_q < 0.05
)
draw_heatmap(
  difference_matrix,
  file.path(visual_dir, "qqq_minus_spy_prior_return_pearson_difference_heatmap.png"),
  "How much does the cross-asset correlation change from SPY to QQQ?",
  "Cell values are QQQ Pearson correlation minus SPY Pearson correlation; descriptive comparison only",
  "%+.3f"
)

draw_three_way_comparison <- function(output_path) {
  matrices <- list(
    "TSLA past -> TSLA future" = own_pearson,
    "QQQ past -> TSLA future" = qqq_pearson,
    "SPY past -> TSLA future" = spy_pearson
  )
  panel_subtitles <- c(
    "mean r +0.028 | max +0.092 at 5 prior / 10 forward",
    "map r vs TSLA-own +0.906 | max +0.134 at 10 / 10",
    "map r vs TSLA-own +0.965 | max +0.111 at 10 / 5"
  )
  shared_limit <- max(abs(unlist(matrices)), na.rm = TRUE)
  palette <- grDevices::colorRampPalette(c("#D95F5F", "#F7F8FA", "#3D8DFF"))(201)
  grDevices::png(output_path, width = 2760, height = 1040, res = 180)
  graphics::layout(matrix(seq_along(matrices), nrow = 1L))
  graphics::par(
    family = "sans", bg = "white", fg = "#273548", col.axis = "#526070",
    col.lab = "#273548", oma = c(0.5, 0.5, 3.2, 0.5)
  )
  for (panel_index in seq_along(matrices)) {
    values <- matrices[[panel_index]]
    graphics::par(mar = c(5.1, if (panel_index == 1L) 5.7 else 3.7, 4.6, 1.2), mgp = c(3.1, 0.8, 0))
    graphics::image(
      x = seq_along(horizons), y = seq_along(horizons), z = t(values),
      col = palette, zlim = c(-shared_limit, shared_limit), axes = FALSE,
      xlab = "Following TSLA sessions",
      ylab = if (panel_index == 1L) "Prior sessions" else "",
      main = names(matrices)[[panel_index]], cex.main = 1.2, cex.lab = 0.95
    )
    graphics::axis(1, at = seq_along(horizons), labels = horizons, tick = FALSE, cex.axis = 0.77)
    graphics::axis(2, at = seq_along(horizons), labels = horizons, tick = FALSE, las = 1, cex.axis = 0.77)
    for (row in seq_along(horizons)) {
      for (column in seq_along(horizons)) {
        value <- values[row, column]
        label_color <- if (abs(value) > 0.58 * shared_limit) "white" else "#273548"
        graphics::text(column, row, labels = sprintf("%+.2f", value), cex = 0.58, col = label_color)
      }
    }
    graphics::mtext(panel_subtitles[[panel_index]], side = 3, line = 1.0, cex = 0.72, col = "#667384")
    graphics::box(col = "#CDD3DA")
  }
  graphics::mtext(
    "Shared color scale across all three maps | Pearson correlations | 2018-2023",
    side = 3, outer = TRUE, line = 1.0, cex = 1.02, font = 2, col = "#273548"
  )
  grDevices::dev.off()
}

draw_three_way_comparison(
  file.path(visual_dir, "tsla_own_qqq_spy_prior_return_pearson_comparison.png")
)

markdown_matrix <- function(values, digits = 3L) {
  header <- paste(c("Prior \\ Forward", colnames(values)), collapse = " | ")
  separator <- paste(c("---", rep("---:", ncol(values))), collapse = " | ")
  rows <- vapply(seq_len(nrow(values)), function(i) {
    paste(c(rownames(values)[[i]], formatC(values[i, ], format = "f", digits = digits)), collapse = " | ")
  }, character(1))
  paste(c(paste0("| ", header, " |"), paste0("| ", separator, " |"), paste0("| ", rows, " |")), collapse = "\n")
}

summary_lines <- vapply(seq_len(nrow(map_summary)), function(i) {
  row <- map_summary[i, , drop = FALSE]
  sprintf(
    "- %s: mean r `%+.4f`; positive cells `%d/81`; strongest `%+.4f` at `%d` prior / `%d` forward; family BH passes `%d/81`; omnibus passes `%d/81`.",
    row$predictor_symbol, row$mean_pearson, row$positive_cells, row$maximum_cell_pearson,
    row$maximum_cell_prior_sessions, row$maximum_cell_forward_sessions,
    row$family_bh_passes, row$omnibus_bh_passes
  )
}, character(1))
largest_difference <- comparison[which.max(abs(comparison$qqq_minus_spy_pearson)), , drop = FALSE]
report_lines <- c(
  "# QQQ/SPY Prior Return Versus Following TSLA Return",
  "",
  "## Question", "",
  "Does cumulative QQQ or SPY return over one or more completed prior sessions relate to TSLA cumulative return over one or more following sessions?",
  "",
  "## Fixed Surface", "",
  paste0("- Prior QQQ/SPY horizons: `", paste(horizons, collapse = ", "), "` sessions."),
  paste0("- Following TSLA horizons: `", paste(horizons, collapse = ", "), "` sessions."),
  "- Each predictor window ends at anchor close t; each TSLA forward window starts after t.",
  "- Adjusted daily bars, common sessions, 2018-2023 analysis window.",
  "- Pearson correlation / OLS slope with overlap-aware Newey-West/HAC intervals.",
  "- BH-FDR within each 81-cell predictor family and across all 162 signed-return cells.",
  "- The QQQ-minus-SPY map is descriptive; no direct difference test or relative-strength model is opened.",
  "- No post-2023 confirmation, cell selection, trading rule, or performance calculation.",
  "",
  "## QQQ Pearson Matrix", "", markdown_matrix(qqq_pearson), "",
  "## SPY Pearson Matrix", "", markdown_matrix(spy_pearson), "",
  "## QQQ Minus SPY Pearson Matrix", "", markdown_matrix(difference_matrix), "",
  "## Readout", "", summary_lines,
  sprintf(
    "- Largest absolute QQQ-minus-SPY descriptive difference: `%+.4f` at `%d` prior / `%d` forward (QQQ `%+.4f`, SPY `%+.4f`).",
    largest_difference$qqq_minus_spy_pearson, largest_difference$prior_sessions,
    largest_difference$forward_sessions, largest_difference$pearson_correlation_qqq,
    largest_difference$pearson_correlation_spy
  ),
  sprintf("- QQQ/SPY cell-sign agreement: `%d/81`; cellwise map correlation: `%+.4f`.",
          sum(comparison$same_sign), stats::cor(comparison$pearson_correlation_qqq, comparison$pearson_correlation_spy)),
  sprintf("- Versus TSLA's frozen own-prior-return map, QQQ sign agreement is `%d/81` and map correlation is `%+.4f`; SPY sign agreement is `%d/81` and map correlation is `%+.4f`.",
          three_way_summary$sign_agreement_vs_tsla_own[three_way_summary$prior_return_authority == "QQQ"],
          three_way_summary$cellwise_map_correlation_vs_tsla_own[three_way_summary$prior_return_authority == "QQQ"],
          three_way_summary$sign_agreement_vs_tsla_own[three_way_summary$prior_return_authority == "SPY"],
          three_way_summary$cellwise_map_correlation_vs_tsla_own[three_way_summary$prior_return_authority == "SPY"]),
  "- The shared positive island is therefore more consistent with common trend geometry than with a distinct external lead in this aggregate slice.",
  "- These are overlapping, nested cells on one historical sample. Coherent geometry is a clue, not independent replication.",
  "- QQQ and SPY share market shocks with TSLA; the result is association, not causal transmission or independent information.",
  "",
  "## Artifacts", "",
  "- `cross_asset_horizon_grid_statistics.csv`: complete 162-cell table.",
  "- `qqq_vs_spy_cell_comparison.csv`: aligned descriptive map comparison.",
  "- `tsla_own_qqq_spy_cell_comparison.csv` and `tsla_own_qqq_spy_map_summary.csv`: frozen own-versus-external baseline comparison.",
  "- Matrix CSVs: QQQ and SPY Pearson, family BH q, and QQQ-minus-SPY difference.",
  "- `predictor_map_summary.csv`: compact predictor-level readout.",
  "- `visuals/`: QQQ, SPY, difference, and shared-scale TSLA-own/QQQ/SPY comparison heatmaps."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

cat("QQQ/SPY prior-return versus TSLA future-return grid complete.\n")
cat("Cells:", nrow(grid), "\n")
cat("Observations per cell:", min(grid$observations), "to", max(grid$observations), "\n")
for (i in seq_len(nrow(map_summary))) {
  row <- map_summary[i, , drop = FALSE]
  cat(row$predictor_symbol, "strongest:", sprintf("%+.4f", row$maximum_cell_pearson),
      "at", row$maximum_cell_prior_sessions, "prior /", row$maximum_cell_forward_sessions,
      "forward; family BH passes:", row$family_bh_passes, "\n")
}
cat("Output:", output_dir, "\n")
