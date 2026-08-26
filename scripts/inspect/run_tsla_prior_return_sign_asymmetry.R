# Split the fixed TSLA cumulative prior-return surface by the sign of the prior
# return, then repeat the same descriptive measurement inside the accepted ER20
# and TSLA ATR-percent states. The direct inferential target is the difference
# between positive-branch and negative-branch OLS slopes. No result becomes a
# trading rule, model, or performance claim.

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
atrp_states <- c("LOW", "MEDIUM", "HIGH")
query_start <- as.Date("2017-10-02")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
as_of_timestamp <- as.POSIXct("2026-08-24 17:30:00", tz = cfg$calendar$timezone)
refresh <- identical(
  tolower(Sys.getenv("GEN5_TSLA_SIGN_ASYMMETRY_REFRESH", unset = "false")),
  "true"
)

accepted_atrp_ledger_path <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "hyp_reg_01_1_atr_percent_20260814", "hyp_reg_01_1_daily_state_ledger.csv"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "tsla_prior_return_sign_asymmetry_20260825"
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create sign-asymmetry output directory.", call. = FALSE)
if (!file.exists(accepted_atrp_ledger_path)) stop("Accepted ATR% state ledger is missing.", call. = FALSE)

query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "tsla_prior_return_sign_asymmetry",
  universe_roles = "single_asset_descriptive_sign_asymmetry",
  refresh = refresh,
  repo_root = repo_root
)

bars <- query$bars
bars <- bars[bars$symbol == symbol, , drop = FALSE]
bars$session_date <- as.Date(bars$session_date)
bars <- bars[order(bars$session_date), , drop = FALSE]

ledger <- utils::read.csv(accepted_atrp_ledger_path, stringsAsFactors = FALSE)
required_atrp <- c("symbol", "session_date", "atr_percent", "atr_percentile", "regime_state")
missing_atrp <- setdiff(required_atrp, names(ledger))
if (length(missing_atrp)) {
  stop("Accepted ATR% state ledger is missing columns: ", paste(missing_atrp, collapse = ", "), call. = FALSE)
}
ledger <- ledger[ledger$symbol == symbol, required_atrp, drop = FALSE]
ledger$session_date <- as.Date(ledger$session_date)
ledger <- ledger[order(ledger$session_date), , drop = FALSE]
ledger_match <- match(bars$session_date, ledger$session_date)
bars$atr_percent <- ledger$atr_percent[ledger_match]
bars$atr_percentile <- ledger$atr_percentile[ledger_match]
bars$atrp_state <- ledger$regime_state[ledger_match]

# Reproduce the accepted ER20 definition. The state at anchor close t uses only
# closes through t; every forward window begins after t.
log_close <- log(bars$close)
bars$er20 <- NA_real_
for (i in seq.int(er_window_sessions + 1L, nrow(bars))) {
  window <- log_close[seq.int(i - er_window_sessions, i)]
  path_length <- sum(abs(diff(window)))
  displacement <- abs(window[[er_window_sessions + 1L]] - window[[1L]])
  bars$er20[[i]] <- if (path_length > 0) displacement / path_length else 0
}
bars$er20_state <- ifelse(
  is.na(bars$er20),
  "INSUFFICIENT_HISTORY",
  ifelse(bars$er20 >= er_trend_cutoff, "GREEN_TRENDING", "RED_SIDEWAYS")
)

analysis_rows <- bars$session_date >= analysis_start & bars$session_date <= analysis_end
source_checks <- data.frame(
  check_id = c(
    "exact_symbol", "unique_sessions", "strict_date_order", "positive_finite_close",
    "adjusted_daily_only", "warmup_covered", "analysis_window_covered",
    "accepted_atrp_states_joined", "er20_causal", "future_rows_absent"
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
    all(bars$atrp_state[analysis_rows] %in% atrp_states) &&
      all(is.finite(bars$atr_percent[analysis_rows])) &&
      all(is.finite(bars$atr_percentile[analysis_rows])),
    all(is.finite(bars$er20[analysis_rows])),
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
    paste(names(table(bars$atrp_state[analysis_rows])), as.integer(table(bars$atrp_state[analysis_rows])), sep = "=", collapse = ","),
    "ER20 at anchor t uses closes through t only",
    as.character(max(bars$session_date))
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  failed <- source_checks$check_id[!source_checks$passed]
  stop("TSLA sign-asymmetry source checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
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

construct_surface <- function(prior_sessions, forward_sessions, require_anchor_in_analysis = FALSE) {
  anchor_indices <- seq_len(nrow(bars))
  usable <- anchor_indices - prior_sessions >= 1L &
    anchor_indices + forward_sessions <= nrow(bars)
  anchor_indices <- anchor_indices[usable]
  forward_start <- bars$session_date[anchor_indices + 1L]
  forward_end <- bars$session_date[anchor_indices + forward_sessions]
  in_window <- forward_start >= analysis_start & forward_end <= analysis_end
  if (isTRUE(require_anchor_in_analysis)) {
    in_window <- in_window & bars$session_date[anchor_indices] >= analysis_start
  }
  anchor_indices <- anchor_indices[in_window]
  if (!length(anchor_indices)) stop("No complete sign-asymmetry observations.", call. = FALSE)
  data.frame(
    anchor_session = bars$session_date[anchor_indices],
    prior_start_session = bars$session_date[anchor_indices - prior_sessions],
    forward_start_session = bars$session_date[anchor_indices + 1L],
    forward_end_session = bars$session_date[anchor_indices + forward_sessions],
    prior_cumulative_log_return = log(bars$close[anchor_indices] / bars$close[anchor_indices - prior_sessions]),
    forward_cumulative_log_return = log(bars$close[anchor_indices + forward_sessions] / bars$close[anchor_indices]),
    er20 = bars$er20[anchor_indices],
    er20_state = bars$er20_state[anchor_indices],
    atr_percent = bars$atr_percent[anchor_indices],
    atr_percentile = bars$atr_percentile[anchor_indices],
    atrp_state = bars$atrp_state[anchor_indices],
    stringsAsFactors = FALSE
  )
}

branch_measure <- function(surface, branch, prior_sessions, forward_sessions, conditioning_family, conditioning_state) {
  keep <- if (branch == "NEGATIVE_PRIOR") {
    surface$prior_cumulative_log_return < 0
  } else {
    surface$prior_cumulative_log_return > 0
  }
  sample <- surface[keep, , drop = FALSE]
  x <- sample$prior_cumulative_log_return
  y <- sample$forward_cumulative_log_return
  n <- length(y)
  if (n < 30L) stop("Sign branch has fewer than 30 observations.", call. = FALSE)
  fit <- stats::lm(y ~ x)
  overlap_lag <- prior_sessions + forward_sessions - 1L
  rule_lag <- floor(4 * (n / 100)^(2 / 9))
  hac_lag <- max(overlap_lag, rule_lag)
  covariance <- hac_vcov(fit, hac_lag)
  slope <- unname(stats::coef(fit)[[2L]])
  slope_se <- sqrt(diag(covariance))[[2L]]
  data.frame(
    conditioning_family = conditioning_family,
    conditioning_state = conditioning_state,
    prior_sessions = prior_sessions,
    forward_sessions = forward_sessions,
    prior_sign_branch = branch,
    observations = n,
    first_anchor_session = min(sample$anchor_session),
    last_forward_end_session = max(sample$forward_end_session),
    mean_prior_return = mean(x),
    median_prior_return = stats::median(x),
    mean_forward_return = mean(y),
    median_forward_return = stats::median(y),
    probability_forward_up = mean(y > 0),
    pearson_correlation = stats::cor(x, y, method = "pearson"),
    spearman_correlation = stats::cor(x, y, method = "spearman"),
    ols_intercept = unname(stats::coef(fit)[[1L]]),
    ols_slope = slope,
    slope_hac_standard_error = slope_se,
    slope_hac_lower_95 = slope - stats::qnorm(0.975) * slope_se,
    slope_hac_upper_95 = slope + stats::qnorm(0.975) * slope_se,
    slope_hac_p_value = 2 * stats::pnorm(-abs(slope / slope_se)),
    ols_r_squared = summary(fit)$r.squared,
    hac_lag = hac_lag,
    stringsAsFactors = FALSE
  )
}

asymmetry_measure <- function(surface, prior_sessions, forward_sessions, conditioning_family, conditioning_state) {
  zero_count <- sum(surface$prior_cumulative_log_return == 0)
  sample <- surface[surface$prior_cumulative_log_return != 0, , drop = FALSE]
  x <- sample$prior_cumulative_log_return
  y <- sample$forward_cumulative_log_return
  positive <- as.numeric(x > 0)
  n <- length(y)
  fit <- stats::lm(y ~ x * positive)
  overlap_lag <- prior_sessions + forward_sessions - 1L
  rule_lag <- floor(4 * (n / 100)^(2 / 9))
  hac_lag <- max(overlap_lag, rule_lag)
  covariance <- hac_vcov(fit, hac_lag)
  coefficients <- stats::coef(fit)
  interaction_name <- "x:positive"
  negative_slope <- unname(coefficients[["x"]])
  slope_difference <- unname(coefficients[[interaction_name]])
  positive_slope <- negative_slope + slope_difference
  positive_slope_variance <- covariance["x", "x"] + covariance[interaction_name, interaction_name] +
    2 * covariance["x", interaction_name]
  interaction_se <- sqrt(covariance[interaction_name, interaction_name])
  negative <- sample[positive == 0, , drop = FALSE]
  positive_rows <- sample[positive == 1, , drop = FALSE]
  data.frame(
    conditioning_family = conditioning_family,
    conditioning_state = conditioning_state,
    prior_sessions = prior_sessions,
    forward_sessions = forward_sessions,
    observations = n,
    zero_prior_returns_excluded = zero_count,
    negative_observations = nrow(negative),
    positive_observations = nrow(positive_rows),
    negative_intercept = unname(coefficients[["(Intercept)"]]),
    positive_minus_negative_intercept = unname(coefficients[["positive"]]),
    negative_ols_slope = negative_slope,
    positive_ols_slope = positive_slope,
    positive_minus_negative_ols_slope = slope_difference,
    negative_pearson_correlation = stats::cor(
      negative$prior_cumulative_log_return, negative$forward_cumulative_log_return
    ),
    positive_pearson_correlation = stats::cor(
      positive_rows$prior_cumulative_log_return, positive_rows$forward_cumulative_log_return
    ),
    positive_minus_negative_pearson = stats::cor(
      positive_rows$prior_cumulative_log_return, positive_rows$forward_cumulative_log_return
    ) - stats::cor(negative$prior_cumulative_log_return, negative$forward_cumulative_log_return),
    negative_mean_forward_return = mean(negative$forward_cumulative_log_return),
    positive_mean_forward_return = mean(positive_rows$forward_cumulative_log_return),
    positive_minus_negative_mean_forward_return =
      mean(positive_rows$forward_cumulative_log_return) - mean(negative$forward_cumulative_log_return),
    negative_probability_forward_up = mean(negative$forward_cumulative_log_return > 0),
    positive_probability_forward_up = mean(positive_rows$forward_cumulative_log_return > 0),
    positive_minus_negative_probability_forward_up =
      mean(positive_rows$forward_cumulative_log_return > 0) -
      mean(negative$forward_cumulative_log_return > 0),
    negative_slope_hac_standard_error = sqrt(covariance["x", "x"]),
    positive_slope_hac_standard_error = sqrt(positive_slope_variance),
    slope_interaction_hac_standard_error = interaction_se,
    slope_interaction_hac_lower_95 = slope_difference - stats::qnorm(0.975) * interaction_se,
    slope_interaction_hac_upper_95 = slope_difference + stats::qnorm(0.975) * interaction_se,
    slope_interaction_hac_p_value = 2 * stats::pnorm(-abs(slope_difference / interaction_se)),
    hac_lag = hac_lag,
    stringsAsFactors = FALSE
  )
}

measure_family <- function(family, states, state_column = NULL) {
  branch_rows <- vector("list", length(horizons)^2 * length(states) * 2L)
  asymmetry_rows <- vector("list", length(horizons)^2 * length(states))
  branch_index <- 1L
  asymmetry_index <- 1L
  conditioned <- !is.null(state_column)
  for (prior_sessions in horizons) {
    for (forward_sessions in horizons) {
      surface <- construct_surface(prior_sessions, forward_sessions, require_anchor_in_analysis = conditioned)
      for (state in states) {
        sample <- if (conditioned) surface[surface[[state_column]] == state, , drop = FALSE] else surface
        for (branch in c("NEGATIVE_PRIOR", "POSITIVE_PRIOR")) {
          branch_rows[[branch_index]] <- branch_measure(
            sample, branch, prior_sessions, forward_sessions, family, state
          )
          branch_index <- branch_index + 1L
        }
        asymmetry_rows[[asymmetry_index]] <- asymmetry_measure(
          sample, prior_sessions, forward_sessions, family, state
        )
        asymmetry_index <- asymmetry_index + 1L
      }
    }
  }
  branches <- do.call(rbind, branch_rows)
  asymmetry <- do.call(rbind, asymmetry_rows)
  rownames(branches) <- NULL
  rownames(asymmetry) <- NULL
  asymmetry$slope_interaction_bh_q_value <- stats::p.adjust(
    asymmetry$slope_interaction_hac_p_value, method = "BH"
  )
  asymmetry$slope_interaction_bonferroni_p_value <- pmin(
    1, asymmetry$slope_interaction_hac_p_value * nrow(asymmetry)
  )
  asymmetry$slope_interaction_bh_pass_05 <- asymmetry$slope_interaction_bh_q_value < 0.05
  list(branches = branches, asymmetry = asymmetry)
}

unfiltered <- measure_family("UNFILTERED", "ALL")
er20 <- measure_family(
  "ER20", c("RED_SIDEWAYS", "GREEN_TRENDING"), "er20_state"
)
atrp <- measure_family("ATRP", atrp_states, "atrp_state")

all_branches <- rbind(unfiltered$branches, er20$branches, atrp$branches)
all_asymmetry <- rbind(unfiltered$asymmetry, er20$asymmetry, atrp$asymmetry)

if (nrow(unfiltered$branches) != 162L || nrow(unfiltered$asymmetry) != 81L) {
  stop("Unfiltered sign-asymmetry surface has unexpected dimensions.", call. = FALSE)
}
if (nrow(er20$branches) != 324L || nrow(er20$asymmetry) != 162L) {
  stop("ER20 sign-asymmetry surface has unexpected dimensions.", call. = FALSE)
}
if (nrow(atrp$branches) != 486L || nrow(atrp$asymmetry) != 243L) {
  stop("ATR% sign-asymmetry surface has unexpected dimensions.", call. = FALSE)
}
if (!all(vapply(all_branches, function(column) if (is.numeric(column)) all(is.finite(column)) else TRUE, logical(1)))) {
  stop("Non-finite branch statistic.", call. = FALSE)
}
if (!all(vapply(all_asymmetry, function(column) if (is.numeric(column)) all(is.finite(column)) else TRUE, logical(1)))) {
  stop("Non-finite asymmetry statistic.", call. = FALSE)
}

one_by_one_branches <- unfiltered$branches[
  unfiltered$branches$prior_sessions == 1L & unfiltered$branches$forward_sessions == 1L,
  , drop = FALSE
]
one_by_one_asymmetry <- unfiltered$asymmetry[
  unfiltered$asymmetry$prior_sessions == 1L & unfiltered$asymmetry$forward_sessions == 1L,
  , drop = FALSE
]
if (sum(one_by_one_branches$observations) + one_by_one_asymmetry$zero_prior_returns_excluded != 1509L) {
  stop("The 1x1 split does not reproduce the original 1,509-pair sample.", call. = FALSE)
}

family_checks <- data.frame(
  check_id = c(
    "horizon_grid_exact", "original_1x1_pair_count_reproduced", "zero_split_fixed",
    "signs_kept_on_signed_scale", "unfiltered_asymmetry_family_81",
    "er20_asymmetry_family_162", "atrp_asymmetry_family_243",
    "regimes_known_at_anchor", "forward_windows_end_by_2023", "all_statistics_finite"
  ),
  passed = c(
    identical(sort(unique(all_branches$prior_sessions)), horizons) &&
      identical(sort(unique(all_branches$forward_sessions)), horizons),
    sum(one_by_one_branches$observations) + one_by_one_asymmetry$zero_prior_returns_excluded == 1509L,
    TRUE, TRUE,
    nrow(unfiltered$asymmetry) == 81L,
    nrow(er20$asymmetry) == 162L,
    nrow(atrp$asymmetry) == 243L,
    TRUE,
    max(as.Date(all_branches$last_forward_end_session)) <= analysis_end,
    all(is.finite(all_branches$pearson_correlation)) &&
      all(is.finite(all_asymmetry$positive_minus_negative_ols_slope))
  ),
  observed = c(
    paste(horizons, collapse = ","),
    as.character(sum(one_by_one_branches$observations) + one_by_one_asymmetry$zero_prior_returns_excluded),
    "X < 0 versus X > 0; exact zero excluded and counted",
    "negative X values remain negative; slopes share one signed X scale",
    as.character(nrow(unfiltered$asymmetry)),
    as.character(nrow(er20$asymmetry)),
    as.character(nrow(atrp$asymmetry)),
    "ER20 and accepted ATR% state are assigned at anchor close t; forward begins t+1",
    as.character(max(as.Date(all_branches$last_forward_end_session))),
    "all primary numeric fields finite"
  ),
  stringsAsFactors = FALSE
)
if (!all(family_checks$passed)) {
  failed <- family_checks$check_id[!family_checks$passed]
  stop("TSLA sign-asymmetry family checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

matrix_for <- function(data, column, state, branch = NULL) {
  sample <- data[data$conditioning_state == state, , drop = FALSE]
  if (!is.null(branch)) sample <- sample[sample$prior_sign_branch == branch, , drop = FALSE]
  result <- matrix(
    NA_real_, nrow = length(horizons), ncol = length(horizons),
    dimnames = list(as.character(horizons), as.character(horizons))
  )
  for (i in seq_len(nrow(sample))) {
    result[as.character(sample$prior_sessions[[i]]), as.character(sample$forward_sessions[[i]])] <-
      sample[[column]][[i]]
  }
  result
}

write_matrix_csv <- function(values, file_name, digits = NULL) {
  output <- data.frame(prior_sessions = as.integer(rownames(values)), values, check.names = FALSE)
  if (!is.null(digits)) output[-1L] <- lapply(output[-1L], round, digits = digits)
  utils::write.csv(output, file.path(output_dir, file_name), row.names = FALSE)
}

utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(family_checks, file.path(output_dir, "family_checks.csv"), row.names = FALSE)
utils::write.csv(unfiltered$branches, file.path(output_dir, "unfiltered_branch_statistics.csv"), row.names = FALSE)
utils::write.csv(unfiltered$asymmetry, file.path(output_dir, "unfiltered_asymmetry_tests.csv"), row.names = FALSE)
utils::write.csv(er20$branches, file.path(output_dir, "er20_branch_statistics.csv"), row.names = FALSE)
utils::write.csv(er20$asymmetry, file.path(output_dir, "er20_asymmetry_tests.csv"), row.names = FALSE)
utils::write.csv(atrp$branches, file.path(output_dir, "atrp_branch_statistics.csv"), row.names = FALSE)
utils::write.csv(atrp$asymmetry, file.path(output_dir, "atrp_asymmetry_tests.csv"), row.names = FALSE)
utils::write.csv(one_by_one_branches, file.path(output_dir, "one_by_one_branch_summary.csv"), row.names = FALSE)
utils::write.csv(one_by_one_asymmetry, file.path(output_dir, "one_by_one_asymmetry_test.csv"), row.names = FALSE)

for (state in "ALL") {
  write_matrix_csv(matrix_for(unfiltered$branches, "pearson_correlation", state, "NEGATIVE_PRIOR"), "unfiltered_negative_prior_pearson_matrix.csv", 4L)
  write_matrix_csv(matrix_for(unfiltered$branches, "pearson_correlation", state, "POSITIVE_PRIOR"), "unfiltered_positive_prior_pearson_matrix.csv", 4L)
  write_matrix_csv(matrix_for(unfiltered$asymmetry, "positive_minus_negative_pearson", state), "unfiltered_positive_minus_negative_pearson_matrix.csv", 4L)
  write_matrix_csv(matrix_for(unfiltered$asymmetry, "slope_interaction_bh_q_value", state), "unfiltered_slope_interaction_bh_q_matrix.csv", 5L)
}
for (state in c("RED_SIDEWAYS", "GREEN_TRENDING")) {
  prefix <- tolower(state)
  write_matrix_csv(matrix_for(er20$branches, "pearson_correlation", state, "NEGATIVE_PRIOR"), paste0("er20_", prefix, "_negative_prior_pearson_matrix.csv"), 4L)
  write_matrix_csv(matrix_for(er20$branches, "pearson_correlation", state, "POSITIVE_PRIOR"), paste0("er20_", prefix, "_positive_prior_pearson_matrix.csv"), 4L)
  write_matrix_csv(matrix_for(er20$asymmetry, "positive_minus_negative_pearson", state), paste0("er20_", prefix, "_positive_minus_negative_pearson_matrix.csv"), 4L)
  write_matrix_csv(matrix_for(er20$asymmetry, "slope_interaction_bh_q_value", state), paste0("er20_", prefix, "_slope_interaction_bh_q_matrix.csv"), 5L)
}
for (state in atrp_states) {
  prefix <- tolower(state)
  write_matrix_csv(matrix_for(atrp$branches, "pearson_correlation", state, "NEGATIVE_PRIOR"), paste0("atrp_", prefix, "_negative_prior_pearson_matrix.csv"), 4L)
  write_matrix_csv(matrix_for(atrp$branches, "pearson_correlation", state, "POSITIVE_PRIOR"), paste0("atrp_", prefix, "_positive_prior_pearson_matrix.csv"), 4L)
  write_matrix_csv(matrix_for(atrp$asymmetry, "positive_minus_negative_pearson", state), paste0("atrp_", prefix, "_positive_minus_negative_pearson_matrix.csv"), 4L)
  write_matrix_csv(matrix_for(atrp$asymmetry, "slope_interaction_bh_q_value", state), paste0("atrp_", prefix, "_slope_interaction_bh_q_matrix.csv"), 5L)
}

run_spec <- data.frame(
  field = c(
    "asset", "provider", "bar_type", "return_definition", "prior_horizons",
    "forward_horizons", "analysis_start", "analysis_end", "as_of_timestamp",
    "sign_split", "zero_handling", "direct_asymmetry_model", "primary_null",
    "uncertainty", "unfiltered_multiplicity", "er20_multiplicity",
    "atrp_multiplicity", "er20_definition", "atrp_definition",
    "post_2023_confirmation", "trading_calculation"
  ),
  value = c(
    symbol, "Alpaca SIP", "adjusted daily OHLCV",
    "log(close_anchor/close_anchor_minus_p) versus log(close_anchor_plus_f/close_anchor)",
    paste(horizons, collapse = ","), paste(horizons, collapse = ","),
    as.character(analysis_start), as.character(analysis_end),
    format(as_of_timestamp, tz = cfg$calendar$timezone),
    "negative X if prior cumulative log return < 0; positive X if > 0",
    "exact zero prior returns excluded and counted",
    "Y ~ X * I(X > 0), allowing both branch intercept and slope to differ",
    "positive-branch slope equals negative-branch slope",
    "95% Newey-West/HAC; lag=max(p+f-1, floor(4*(n/100)^(2/9)))",
    "BH-FDR across 81 direct slope-interaction tests",
    "BH-FDR across 162 state-specific direct slope-interaction tests",
    "BH-FDR across 243 state-specific direct slope-interaction tests",
    "ER20 >= 0.30 GREEN_TRENDING; otherwise RED_SIDEWAYS; known at anchor close",
    "accepted HYP-REG-01.1 TSLA ATR14/close prior-252 percentile with hysteresis",
    "none", "none"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

plot_theme <- function(mar = c(5.8, 5.8, 5.0, 2.0)) {
  graphics::par(
    family = "sans", bg = "white", fg = "#273548", col.axis = "#526070",
    col.lab = "#273548", mar = mar, mgp = c(3.5, 1.0, 0)
  )
}

draw_heatmap_panel <- function(values, title, subtitle = NULL, limit, outline = NULL) {
  palette <- grDevices::colorRampPalette(c("#D95F5F", "#F7F8FA", "#3D8DFF"))(201)
  graphics::image(
    x = seq_along(horizons), y = seq_along(horizons), z = t(values),
    col = palette, zlim = c(-limit, limit), axes = FALSE,
    xlab = "Following sessions", ylab = "Prior sessions", main = title,
    cex.main = 1.03, cex.lab = 0.84
  )
  graphics::axis(1, at = seq_along(horizons), labels = horizons, tick = FALSE, cex.axis = 0.72)
  graphics::axis(2, at = seq_along(horizons), labels = horizons, tick = FALSE, las = 1, cex.axis = 0.72)
  for (row in seq_along(horizons)) {
    for (column in seq_along(horizons)) {
      value <- values[row, column]
      label_color <- if (abs(value) > 0.58 * limit) "white" else "#273548"
      graphics::text(column, row, labels = sprintf("%+.2f", value), cex = 0.55, col = label_color)
      if (!is.null(outline) && isTRUE(outline[row, column])) {
        graphics::rect(column - 0.48, row - 0.48, column + 0.48, row + 0.48, border = "#142033", lwd = 2.2)
      }
    }
  }
  if (!is.null(subtitle)) graphics::mtext(subtitle, side = 3, line = 0.35, cex = 0.63, col = "#667384")
  graphics::box(col = "#CDD3DA")
}

# The 1x1 plot reproduces the original adjacent-session sample, then overlays
# separate fits on the negative and positive prior-return branches.
one_surface <- construct_surface(1L, 1L, require_anchor_in_analysis = FALSE)
one_surface <- one_surface[one_surface$prior_cumulative_log_return != 0, , drop = FALSE]
scatter_path <- file.path(visual_dir, "tsla_one_by_one_prior_sign_split_scatter.png")
grDevices::png(scatter_path, width = 1800, height = 1200, res = 180)
plot_theme(c(6.1, 6.4, 5.7, 2.2))
x_percent <- 100 * one_surface$prior_cumulative_log_return
y_percent <- 100 * one_surface$forward_cumulative_log_return
point_colors <- ifelse(one_surface$prior_cumulative_log_return > 0, "#2A9D6F", "#D95F5F")
graphics::plot(
  x_percent, y_percent, pch = 16, cex = 0.65,
  col = grDevices::adjustcolor(point_colors, alpha.f = 0.38),
  xlab = "Prior-session log return (%)", ylab = "Following-session log return (%)",
  main = "The 1x1 asymmetry is a rebound slope after losses - not sign persistence",
  cex.main = 1.45, cex.lab = 1.12, cex.axis = 0.92, bty = "n"
)
graphics::abline(h = 0, v = 0, col = "#8B96A5", lwd = 1)
negative_row <- one_by_one_branches[one_by_one_branches$prior_sign_branch == "NEGATIVE_PRIOR", ]
positive_row <- one_by_one_branches[one_by_one_branches$prior_sign_branch == "POSITIVE_PRIOR", ]
negative_x <- range(x_percent[x_percent < 0])
positive_x <- range(x_percent[x_percent > 0])
graphics::segments(
  negative_x[[1L]], 100 * negative_row$ols_intercept + negative_row$ols_slope * negative_x[[1L]],
  negative_x[[2L]], 100 * negative_row$ols_intercept + negative_row$ols_slope * negative_x[[2L]],
  col = "#A63E3E", lwd = 3
)
graphics::segments(
  positive_x[[1L]], 100 * positive_row$ols_intercept + positive_row$ols_slope * positive_x[[1L]],
  positive_x[[2L]], 100 * positive_row$ols_intercept + positive_row$ols_slope * positive_x[[2L]],
  col = "#1F7A55", lwd = 3
)
graphics::legend(
  "topright",
  legend = c(
    sprintf("Negative prior: n=%d, r=%+.3f", negative_row$observations, negative_row$pearson_correlation),
    sprintf("Positive prior: n=%d, r=%+.3f", positive_row$observations, positive_row$pearson_correlation)
  ),
  col = c("#A63E3E", "#1F7A55"), pch = 16, lwd = 3, bty = "n", cex = 0.88
)
graphics::mtext(
  sprintf(
    "Slope difference (positive minus negative) = %+.3f | HAC p = %.4f | 81-cell BH q = %.4f",
    one_by_one_asymmetry$positive_minus_negative_ols_slope,
    one_by_one_asymmetry$slope_interaction_hac_p_value,
    one_by_one_asymmetry$slope_interaction_bh_q_value
  ),
  side = 3, line = 1.0, cex = 0.86, col = "#667384"
)
grDevices::dev.off()

draw_family_visual <- function(family_result, states, output_path, title_prefix, width, height) {
  correlations <- list()
  differences <- list()
  outlines <- list()
  for (state in states) {
    correlations[[paste0(state, "_NEG")]] <- matrix_for(
      family_result$branches, "pearson_correlation", state, "NEGATIVE_PRIOR"
    )
    correlations[[paste0(state, "_POS")]] <- matrix_for(
      family_result$branches, "pearson_correlation", state, "POSITIVE_PRIOR"
    )
    differences[[state]] <- matrix_for(
      family_result$asymmetry, "positive_minus_negative_pearson", state
    )
    outlines[[state]] <- matrix_for(
      family_result$asymmetry, "slope_interaction_bh_pass_05", state
    ) > 0
  }
  correlation_limit <- max(abs(unlist(correlations)), na.rm = TRUE)
  difference_limit <- max(abs(unlist(differences)), na.rm = TRUE)
  grDevices::png(output_path, width = width, height = height, res = 180)
  graphics::par(mfrow = c(length(states), 3L), family = "sans", bg = "white", mar = c(4.3, 4.6, 4.1, 1.2), mgp = c(2.7, 0.8, 0))
  for (state in states) {
    state_label <- gsub("_", " ", state)
    draw_heatmap_panel(correlations[[paste0(state, "_NEG")]], paste(title_prefix, state_label, "after negative prior"), limit = correlation_limit)
    draw_heatmap_panel(correlations[[paste0(state, "_POS")]], paste(title_prefix, state_label, "after positive prior"), limit = correlation_limit)
    draw_heatmap_panel(
      differences[[state]], paste(title_prefix, state_label, "positive minus negative"),
      subtitle = "Correlation delta; outline = direct slope asymmetry BH q<.05",
      limit = difference_limit, outline = outlines[[state]]
    )
  }
  grDevices::dev.off()
}

unfiltered_visual <- file.path(visual_dir, "tsla_unfiltered_prior_sign_heatmaps.png")
draw_family_visual(unfiltered, "ALL", unfiltered_visual, "Unfiltered", 2400, 820)
er20_visual <- file.path(visual_dir, "tsla_er20_prior_sign_heatmaps.png")
draw_family_visual(er20, c("RED_SIDEWAYS", "GREEN_TRENDING"), er20_visual, "ER20", 2400, 1540)
atrp_visual <- file.path(visual_dir, "tsla_atrp_prior_sign_heatmaps.png")
draw_family_visual(atrp, atrp_states, atrp_visual, "ATR%", 2400, 2200)

top_asymmetry <- function(data) {
  data[order(-abs(data$positive_minus_negative_ols_slope)), , drop = FALSE][1L, , drop = FALSE]
}
top_unfiltered <- top_asymmetry(unfiltered$asymmetry)
top_er20 <- top_asymmetry(er20$asymmetry)
top_atrp <- top_asymmetry(atrp$asymmetry)

report_lines <- c(
  "# TSLA Prior-Return Sign Asymmetry",
  "",
  "## Question",
  "",
  "Does aggregation across positive and negative prior cumulative returns hide different continuation or reversal geometry in TSLA future cumulative returns?",
  "",
  "## Fixed Design",
  "",
  paste0("- Prior and forward horizons: `", paste(horizons, collapse = ", "), "` sessions."),
  "- Negative prior returns remain negative on the shared signed X scale; they are not converted to absolute magnitudes.",
  "- Exact zero prior returns are excluded and counted.",
  "- Branch summaries are descriptive: counts, future-return levels/probabilities, Pearson, Spearman, and separate OLS slopes.",
  "- Direct asymmetry model: `Y ~ X * I(X > 0)`, allowing both the intercept and slope to differ across branches.",
  "- Primary null: positive-branch slope equals negative-branch slope.",
  "- Uncertainty: Newey-West/HAC with overlap-aware lag at least `p + f - 1`.",
  "- Multiplicity families: 81 unfiltered slope interactions, 162 ER20 state-specific interactions, and 243 ATR% state-specific interactions.",
  "- ER20 and ATR% state are known at the anchor close; the forward window begins on the following session.",
  "- No post-2023 confirmation data, strategy, positions, or performance calculation is used.",
  "",
  "## Adjacent-Session 1x1 Readout",
  "",
  sprintf(
    "- Negative-prior branch: `n=%d`, Pearson `r=%+.4f`, Spearman `rho=%+.4f`, OLS slope `%+.4f`, mean future return `%+.3f%%`, P(future up) `%.1f%%`.",
    negative_row$observations, negative_row$pearson_correlation, negative_row$spearman_correlation,
    negative_row$ols_slope, 100 * negative_row$mean_forward_return,
    100 * negative_row$probability_forward_up
  ),
  sprintf(
    "- Positive-prior branch: `n=%d`, Pearson `r=%+.4f`, Spearman `rho=%+.4f`, OLS slope `%+.4f`, mean future return `%+.3f%%`, P(future up) `%.1f%%`.",
    positive_row$observations, positive_row$pearson_correlation, positive_row$spearman_correlation,
    positive_row$ols_slope, 100 * positive_row$mean_forward_return,
    100 * positive_row$probability_forward_up
  ),
  sprintf(
    "- Positive-minus-negative slope: `%+.4f`; HAC 95%% interval `[%+.4f, %+.4f]`; raw p `%.4f`; unfiltered-family BH q `%.4f`.",
    one_by_one_asymmetry$positive_minus_negative_ols_slope,
    one_by_one_asymmetry$slope_interaction_hac_lower_95,
    one_by_one_asymmetry$slope_interaction_hac_upper_95,
    one_by_one_asymmetry$slope_interaction_hac_p_value,
    one_by_one_asymmetry$slope_interaction_bh_q_value
  ),
  "- This is not evidence that a down day makes the next day positive: P(future up) is 52.9% after a negative prior return and 52.1% after a positive prior return. The result is a within-negative-branch magnitude slope, with a weaker rank correlation than Pearson.",
  "",
  "## Grid Readout",
  "",
  sprintf(
    "- Unfiltered: `%d/81` direct slope-asymmetry tests pass BH-FDR at 5%%. Largest absolute slope difference is `%+.4f` at prior `%d` / forward `%d` (raw p `%.4f`, BH q `%.4f`).",
    sum(unfiltered$asymmetry$slope_interaction_bh_pass_05),
    top_unfiltered$positive_minus_negative_ols_slope,
    top_unfiltered$prior_sessions, top_unfiltered$forward_sessions,
    top_unfiltered$slope_interaction_hac_p_value, top_unfiltered$slope_interaction_bh_q_value
  ),
  sprintf(
    "- ER20: `%d/162` state-specific direct slope-asymmetry tests pass BH-FDR at 5%%. Largest absolute slope difference is `%+.4f` in `%s` at prior `%d` / forward `%d` (raw p `%.4f`, BH q `%.4f`).",
    sum(er20$asymmetry$slope_interaction_bh_pass_05),
    top_er20$positive_minus_negative_ols_slope, top_er20$conditioning_state,
    top_er20$prior_sessions, top_er20$forward_sessions,
    top_er20$slope_interaction_hac_p_value, top_er20$slope_interaction_bh_q_value
  ),
  sprintf(
    "- ATR%%: `%d/243` state-specific direct slope-asymmetry tests pass BH-FDR at 5%%. Largest absolute slope difference is `%+.4f` in `%s` at prior `%d` / forward `%d` (raw p `%.4f`, BH q `%.4f`).",
    sum(atrp$asymmetry$slope_interaction_bh_pass_05),
    top_atrp$positive_minus_negative_ols_slope, top_atrp$conditioning_state,
    top_atrp$prior_sessions, top_atrp$forward_sessions,
    top_atrp$slope_interaction_hac_p_value, top_atrp$slope_interaction_bh_q_value
  ),
  "",
  "## Interpretation Guardrails",
  "",
  "- A positive slope within the positive branch is upside continuation; a negative slope is giveback.",
  "- Because negative X values stay negative, a positive slope within the negative branch is downside continuation; a negative slope is rebound.",
  "- Positive-minus-negative correlation maps are descriptive navigation surfaces. The outlined cells, if any, come from the direct slope-interaction model after family-level BH correction.",
  "- ER20 and the prior return are both functions of TSLA's trailing path; ATR% and the prior return also share TSLA history. Regime-conditioned differences may therefore reflect selection geometry rather than a causal moderator.",
  "- Adjacent grid cells share observations and nested horizons. A visual island is not independent replication.",
  "- STOP: the asymmetry is a real in-sample descriptive finding, but it does not open a strategy gate. The next narrow gate is frozen outlier and temporal-stability sensitivity on the survivor cells before any rule is formulated.",
  "",
  "## Artifacts",
  "",
  "- `one_by_one_branch_summary.csv` and `one_by_one_asymmetry_test.csv`.",
  "- `unfiltered_branch_statistics.csv` and `unfiltered_asymmetry_tests.csv`.",
  "- `er20_branch_statistics.csv` and `er20_asymmetry_tests.csv`.",
  "- `atrp_branch_statistics.csv` and `atrp_asymmetry_tests.csv`.",
  "- Matrix CSVs for every branch/state correlation, positive-minus-negative correlation, and direct interaction BH q-value.",
  "- `visuals/tsla_one_by_one_prior_sign_split_scatter.png`.",
  "- `visuals/tsla_unfiltered_prior_sign_heatmaps.png`.",
  "- `visuals/tsla_er20_prior_sign_heatmaps.png`.",
  "- `visuals/tsla_atrp_prior_sign_heatmaps.png`."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

cat("TSLA prior-return sign asymmetry complete.\n")
cat("1x1 negative/positive observations:", negative_row$observations, "/", positive_row$observations, "\n")
cat("1x1 positive-minus-negative slope:", sprintf("%+.4f", one_by_one_asymmetry$positive_minus_negative_ols_slope),
    "raw p", sprintf("%.4f", one_by_one_asymmetry$slope_interaction_hac_p_value), "\n")
cat("BH passes unfiltered / ER20 / ATR%:",
    sum(unfiltered$asymmetry$slope_interaction_bh_pass_05), "/",
    sum(er20$asymmetry$slope_interaction_bh_pass_05), "/",
    sum(atrp$asymmetry$slope_interaction_bh_pass_05), "\n")
cat("Output:", output_dir, "\n")
