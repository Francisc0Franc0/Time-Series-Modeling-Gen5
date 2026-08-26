# Condition the fixed TSLA cumulative-return horizon grid on an accepted
# HYP-REG-01.1 ATR-percent state authority. The default is TSLA itself; a
# caller may set GEN5_ATRP_STATE_SYMBOL=SPY for the frozen external-market
# context slice. This remains descriptive research: no state or cell becomes
# a trading rule, model, or performance claim.

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
state_symbol <- toupper(trimws(Sys.getenv("GEN5_ATRP_STATE_SYMBOL", unset = symbol)))
if (!state_symbol %in% c("TSLA", "SPY")) {
  stop("GEN5_ATRP_STATE_SYMBOL must be TSLA or SPY for this frozen slice.", call. = FALSE)
}
external_state <- state_symbol != symbol
file_stem <- if (external_state) "tsla_spy_atrp" else "tsla_atrp"
horizons <- c(1L, 2L, 3L, 4L, 5L, 10L, 15L, 20L, 25L)
states <- c("LOW", "MEDIUM", "HIGH")
query_start <- as.Date("2017-10-02")
analysis_start <- as.Date("2018-01-02")
analysis_end <- as.Date("2023-12-29")
as_of_timestamp <- as.POSIXct("2026-08-24 17:30:00", tz = cfg$calendar$timezone)
accepted_ledger_path <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  "hyp_reg_01_1_atr_percent_20260814", "hyp_reg_01_1_daily_state_ledger.csv"
)
output_dir <- file.path(
  repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
  if (external_state) {
    "tsla_spy_atrp_conditioned_return_horizon_grid_20260825"
  } else {
    "tsla_atrp_conditioned_return_horizon_grid_20260825"
  }
)
visual_dir <- file.path(output_dir, "visuals")
dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)
if (!dir.exists(visual_dir)) stop("Could not create ATR%-conditioned output directory.", call. = FALSE)
if (!file.exists(accepted_ledger_path)) {
  stop("Accepted HYP-REG-01.1 daily state ledger is missing.", call. = FALSE)
}

ledger_all <- utils::read.csv(accepted_ledger_path, stringsAsFactors = FALSE)
required <- c(
  "symbol", "session_date", "open", "high", "low", "close", "atr",
  "atr_percent", "atr_percentile", "regime_state"
)
missing <- setdiff(required, names(ledger_all))
if (length(missing)) stop("Accepted ATR% ledger is missing columns: ", paste(missing, collapse = ", "), call. = FALSE)

accepted_return <- ledger_all[ledger_all$symbol == symbol, required, drop = FALSE]
accepted_return$session_date <- as.Date(accepted_return$session_date)
accepted_return <- accepted_return[order(accepted_return$session_date), , drop = FALSE]
accepted_state <- ledger_all[ledger_all$symbol == state_symbol, required, drop = FALSE]
accepted_state$session_date <- as.Date(accepted_state$session_date)
accepted_state <- accepted_state[order(accepted_state$session_date), , drop = FALSE]
if (!nrow(accepted_return) || !nrow(accepted_state)) {
  stop("Accepted ATR% ledger is missing the return or state authority symbol.", call. = FALSE)
}

# Reuse the same cached adjusted daily TSLA bars as the aggregate and ER20
# grids so the longest prior horizon has its pre-2018 observations. The
# accepted HYP-REG-01.1 ledger remains the sole authority for anchor states.
query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = query_start,
  end_date = analysis_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbol,
  universe_name = "tsla_atrp_conditioned_return_horizon_grid",
  universe_roles = "single_asset_descriptive_regime_conditioning",
  refresh = FALSE,
  repo_root = repo_root
)
bars <- query$bars[query$bars$symbol == symbol, , drop = FALSE]
bars$session_date <- as.Date(bars$session_date)
bars <- bars[order(bars$session_date), , drop = FALSE]
ledger_index <- match(bars$session_date, accepted_state$session_date)
for (column in c("atr", "atr_percent", "atr_percentile", "regime_state")) {
  bars[[column]] <- accepted_state[[column]][ledger_index]
}

analysis_rows <-
  bars$session_date >= analysis_start & bars$session_date <= analysis_end
state_counts <- table(factor(bars$regime_state[analysis_rows], levels = states))
expected_state_counts <- if (state_symbol == "TSLA") {
  stats::setNames(c(581L, 341L, 587L), states)
} else {
  stats::setNames(c(568L, 430L, 511L), states)
}
accepted_state_match <- match(accepted_state$session_date, bars$session_date)
accepted_return_match <- match(accepted_return$session_date, bars$session_date)
source_checks <- data.frame(
  check_id = c(
    "accepted_ledger_present", "exact_symbol", "unique_sessions", "strict_date_order",
    "finite_valid_ohlc", "adjusted_daily_only", "prehistory_covers_25_prior_sessions", "analysis_window_exact",
    "analysis_row_count_matches_accepted_poc", "state_vocabulary_exact",
    "state_occupancy_matches_accepted_state_ledger", "accepted_state_dates_match_tsla_bars",
    "accepted_tsla_closes_match_bars", "finite_atr_fields", "future_rows_absent"
  ),
  passed = c(
    file.exists(accepted_ledger_path),
    nrow(bars) > 0L && identical(unique(as.character(bars$symbol)), symbol),
    !anyDuplicated(bars$session_date),
    nrow(bars) > 1L && all(diff(bars$session_date) > 0),
    nrow(bars) > 0L && all(is.finite(as.matrix(bars[c("open", "high", "low", "close")]))) &&
      all(bars$open > 0 & bars$high > 0 & bars$low > 0 & bars$close > 0) &&
      all(bars$high >= pmax(bars$open, bars$close, bars$low)) &&
      all(bars$low <= pmin(bars$open, bars$close, bars$high)),
    all(bars$adjusted %in% TRUE) && all(bars$timeframe == "1D"),
    sum(bars$session_date < analysis_start) >= max(horizons),
    min(bars$session_date[analysis_rows]) == analysis_start &&
      max(bars$session_date[analysis_rows]) == analysis_end,
    sum(analysis_rows) == 1509L,
    identical(sort(unique(bars$regime_state[analysis_rows])), sort(states)),
    identical(as.integer(state_counts), as.integer(expected_state_counts)),
    !anyNA(accepted_state_match) && length(accepted_state_match) == sum(analysis_rows),
    !anyNA(accepted_return_match) && isTRUE(all.equal(
      bars$close[accepted_return_match], accepted_return$close, tolerance = 1e-10, check.attributes = FALSE
    )),
    all(is.finite(bars$atr[analysis_rows])) && all(is.finite(bars$atr_percent[analysis_rows])) &&
      all(is.finite(bars$atr_percentile[analysis_rows])) &&
      all(bars$atr_percentile[analysis_rows] >= 0 & bars$atr_percentile[analysis_rows] <= 1),
    max(bars$session_date) <= analysis_end
  ),
  observed = c(
    accepted_ledger_path,
    paste(unique(as.character(bars$symbol)), collapse = ","),
    as.character(sum(duplicated(bars$session_date))),
    if (nrow(bars)) paste(min(bars$session_date), max(bars$session_date), sep = " to ") else "no rows",
    if (nrow(bars)) paste(range(bars$close), collapse = " to ") else "no rows",
    paste(unique(paste(bars$adjusted, bars$timeframe, sep = "/")), collapse = ","),
    as.character(sum(bars$session_date < analysis_start)),
    if (any(analysis_rows)) paste(min(bars$session_date[analysis_rows]), max(bars$session_date[analysis_rows]), sep = " to ") else "no rows",
    as.character(sum(analysis_rows)),
    paste(sort(unique(bars$regime_state[analysis_rows])), collapse = ","),
    paste(names(state_counts), as.integer(state_counts), sep = "=", collapse = ","),
    sprintf("%d/%d %s state dates matched", sum(!is.na(accepted_state_match)), nrow(accepted_state), state_symbol),
    if (!anyNA(accepted_return_match)) sprintf("max abs TSLA close diff %.12f", max(abs(bars$close[accepted_return_match] - accepted_return$close))) else "unmatched dates",
    sprintf("ATR%% %.4f to %.4f; percentile %.4f to %.4f", min(bars$atr_percent[analysis_rows]), max(bars$atr_percent[analysis_rows]), min(bars$atr_percentile[analysis_rows]), max(bars$atr_percentile[analysis_rows])),
    as.character(max(bars$session_date))
  ),
  stringsAsFactors = FALSE
)
if (!all(source_checks$passed)) {
  failed <- source_checks$check_id[!source_checks$passed]
  stop("TSLA return / ", state_symbol, " ATR%-state source checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

# Build one contiguous span per accepted state run. The state labels come from
# the frozen HYP-REG-01.1 ledger; this visual layer does not reconstruct them.
chart_ledger <- data.frame(
  session_date = bars$session_date[analysis_rows],
  adjusted_close = bars$close[analysis_rows],
  state_authority = state_symbol,
  atr_percent = bars$atr_percent[analysis_rows],
  atr_percentile = bars$atr_percentile[analysis_rows],
  atrp_state = bars$regime_state[analysis_rows],
  stringsAsFactors = FALSE
)
state_change <- c(TRUE, chart_ledger$atrp_state[-1L] != chart_ledger$atrp_state[-nrow(chart_ledger)])
span_rows <- split(seq_len(nrow(chart_ledger)), cumsum(state_change))
state_spans <- do.call(rbind, lapply(span_rows, function(rows) {
  end_row <- max(rows)
  next_session <- if (end_row < nrow(chart_ledger)) chart_ledger$session_date[[end_row + 1L]] else analysis_end + 1
  data.frame(
    atrp_state = chart_ledger$atrp_state[[min(rows)]],
    band_start = chart_ledger$session_date[[min(rows)]],
    band_end_exclusive = next_session,
    stringsAsFactors = FALSE
  )
}))
rownames(state_spans) <- NULL

state_colors <- c(
  LOW = grDevices::adjustcolor("#74A7E8", alpha.f = 0.30),
  MEDIUM = grDevices::adjustcolor("#D6B85E", alpha.f = 0.25),
  HIGH = grDevices::adjustcolor("#DD7777", alpha.f = 0.29)
)

draw_state_bands <- function(y_bottom, y_top) {
  for (i in seq_len(nrow(state_spans))) {
    graphics::rect(
      xleft = as.numeric(state_spans$band_start[[i]]),
      ybottom = y_bottom,
      xright = as.numeric(state_spans$band_end_exclusive[[i]]),
      ytop = y_top,
      col = unname(state_colors[state_spans$atrp_state[[i]]]),
      border = NA
    )
  }
}

state_plot_path <- file.path(visual_dir, paste0(file_stem, "_state_price_bands.png"))
grDevices::png(state_plot_path, width = 2400, height = 1350, res = 180)
old_par <- graphics::par(
  family = "sans", bg = "white", fg = "#273548", col.axis = "#526070",
  col.lab = "#273548"
)
graphics::layout(matrix(c(1L, 2L), nrow = 2L), heights = c(3.25, 1.0))

graphics::par(mar = c(1.0, 7.0, 7.3, 2.2), mgp = c(3.9, 1.15, 0))
price_ylim <- range(chart_ledger$adjusted_close)
graphics::plot(
  chart_ledger$session_date, chart_ledger$adjusted_close,
  type = "n", xlim = c(analysis_start, analysis_end), ylim = price_ylim,
  log = "y", xaxt = "n", xlab = "", ylab = "TSLA adjusted close (log scale)",
  main = if (external_state) {
    "SPY volatility state over TSLA price: LOW, MEDIUM, and HIGH ATR% bands"
  } else {
    "TSLA volatility state: LOW, MEDIUM, and HIGH ATR% bands"
  },
  cex.main = 1.55, cex.lab = 1.18, cex.axis = 0.96,
  col.main = "#142033", bty = "n", las = 1
)
graphics::mtext(
  paste0("Accepted HYP-REG-01.1 ", state_symbol, " state | Wilder ATR14 / close | Prior-252 causal percentile with hysteresis | 2018-2023"),
  side = 3, line = 1.0, cex = 0.94, col = "#5C6777"
)
draw_state_bands(price_ylim[[1L]], price_ylim[[2L]])
graphics::grid(nx = NA, ny = NULL, col = grDevices::adjustcolor("#8B96A5", alpha.f = 0.22), lty = 1)
graphics::lines(chart_ledger$session_date, chart_ledger$adjusted_close, col = "#17273B", lwd = 2.15)
graphics::box(bty = "l", col = "#7D8794")
graphics::legend(
  "topleft",
  legend = c(
    paste0(state_symbol, " LOW movement capacity"),
    paste0(state_symbol, " MEDIUM movement capacity"),
    paste0(state_symbol, " HIGH movement capacity"),
    "TSLA adjusted close"
  ),
  fill = c(unname(state_colors[c("LOW", "MEDIUM", "HIGH")]), NA),
  border = rep(NA, 4L), lty = c(NA, NA, NA, 1), lwd = c(NA, NA, NA, 2.15),
  col = c(NA, NA, NA, "#17273B"), bg = grDevices::adjustcolor("white", alpha.f = 0.88),
  box.col = "#C5CBD3", cex = 0.82, inset = 0.015
)

graphics::par(mar = c(5.7, 7.0, 1.1, 2.2), mgp = c(3.6, 1.15, 0))
graphics::plot(
  chart_ledger$session_date, chart_ledger$atr_percentile,
  type = "n", xlim = c(analysis_start, analysis_end), ylim = c(0, 1), xaxt = "n",
  xlab = "Session date", ylab = paste0(state_symbol, " rank"), cex.lab = 1.12,
  cex.axis = 0.94, bty = "n", las = 1
)
draw_state_bands(0, 1)
date_ticks <- as.Date(c("2018-01-02", "2020-01-02", "2022-01-03", "2023-12-29"))
graphics::axis(1, at = date_ticks, labels = c("2018", "2020", "2022", "2023"))
graphics::abline(h = c(0.30, 0.40, 0.60, 0.70), col = "#6E7785", lwd = 1.0, lty = 2)
graphics::lines(chart_ledger$session_date, chart_ledger$atr_percentile, col = "#223A58", lwd = 1.20)
graphics::box(bty = "l", col = "#7D8794")
graphics::mtext(
  paste0("Bands show the accepted ", state_symbol, " hysteretic state at close t. ATR% measures movement capacity, not trend direction or expected return."),
  side = 1, line = 4.25, cex = 0.72, col = "#667384"
)
graphics::par(old_par)
grDevices::dev.off()

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
  forward_end_dates <- bars$session_date[anchor_indices + forward_sessions]
  in_window <-
    bars$session_date[anchor_indices] >= analysis_start &
    forward_end_dates <= analysis_end &
    bars$regime_state[anchor_indices] %in% states
  anchor_indices <- anchor_indices[in_window]
  if (!length(anchor_indices)) stop("No complete ATR%-conditioned observations.", call. = FALSE)

  data.frame(
    anchor_session = bars$session_date[anchor_indices],
    prior_start_session = bars$session_date[anchor_indices - prior_sessions],
    forward_start_session = bars$session_date[anchor_indices + 1L],
    forward_end_session = bars$session_date[anchor_indices + forward_sessions],
    atr_percent = bars$atr_percent[anchor_indices],
    atr_percentile = bars$atr_percentile[anchor_indices],
    regime_state = bars$regime_state[anchor_indices],
    prior_cumulative_log_return = log(bars$close[anchor_indices] / bars$close[anchor_indices - prior_sessions]),
    forward_cumulative_log_return = log(bars$close[anchor_indices + forward_sessions] / bars$close[anchor_indices]),
    stringsAsFactors = FALSE
  )
}

measure_state <- function(surface, state, prior_sessions, forward_sessions) {
  sample <- surface[surface$regime_state == state, , drop = FALSE]
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
    atrp_state = state,
    observations = n,
    first_anchor_session = min(sample$anchor_session),
    last_anchor_session = max(sample$anchor_session),
    mean_atr_percent = mean(sample$atr_percent),
    mean_atr_percentile = mean(sample$atr_percentile),
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
    direction_difference = mean(forward_up[prior_up == 1]) - mean(forward_up[prior_up == 0]),
    same_sign_probability = mean((x > 0) == (y > 0)),
    hac_lag = hac_lag,
    stringsAsFactors = FALSE
  )
}

measure_pairwise <- function(surface, first_state, second_state, prior_sessions, forward_sessions) {
  sample <- surface[surface$regime_state %in% c(first_state, second_state), , drop = FALSE]
  x <- sample$prior_cumulative_log_return
  y <- sample$forward_cumulative_log_return
  second <- as.numeric(sample$regime_state == second_state)
  overlap_lag <- prior_sessions + forward_sessions - 1L
  rule_lag <- floor(4 * (nrow(sample) / 100)^(2 / 9))
  hac_lag <- max(overlap_lag, rule_lag)
  fit <- stats::lm(y ~ x * second)
  covariance <- hac_vcov(fit, hac_lag)
  interaction <- unname(stats::coef(fit)[["x:second"]])
  interaction_se <- sqrt(diag(covariance))[["x:second"]]
  interaction_z <- interaction / interaction_se
  first <- sample[sample$regime_state == first_state, , drop = FALSE]
  second_rows <- sample[sample$regime_state == second_state, , drop = FALSE]
  first_correlation <- stats::cor(first$prior_cumulative_log_return, first$forward_cumulative_log_return)
  second_correlation <- stats::cor(second_rows$prior_cumulative_log_return, second_rows$forward_cumulative_log_return)

  data.frame(
    prior_sessions = prior_sessions,
    forward_sessions = forward_sessions,
    comparison = paste0(second_state, "_MINUS_", first_state),
    first_state = first_state,
    second_state = second_state,
    first_observations = nrow(first),
    second_observations = nrow(second_rows),
    first_pearson_correlation = first_correlation,
    second_pearson_correlation = second_correlation,
    second_minus_first_correlation = second_correlation - first_correlation,
    first_r_squared = first_correlation^2,
    second_r_squared = second_correlation^2,
    second_minus_first_r_squared = second_correlation^2 - first_correlation^2,
    second_minus_first_ols_slope = interaction,
    interaction_hac_standard_error = interaction_se,
    interaction_hac_lower_95 = interaction - stats::qnorm(0.975) * interaction_se,
    interaction_hac_upper_95 = interaction + stats::qnorm(0.975) * interaction_se,
    interaction_hac_p_value = 2 * stats::pnorm(-abs(interaction_z)),
    hac_lag = hac_lag,
    stringsAsFactors = FALSE
  )
}

state_rows <- vector("list", length(horizons)^2 * length(states))
pair_rows <- vector("list", length(horizons)^2 * 3L)
state_index <- 1L
pair_index <- 1L
state_pairs <- list(c("LOW", "MEDIUM"), c("LOW", "HIGH"), c("MEDIUM", "HIGH"))
for (prior_sessions in horizons) {
  for (forward_sessions in horizons) {
    surface <- construct_pair_surface(prior_sessions, forward_sessions)
    for (state in states) {
      state_rows[[state_index]] <- measure_state(surface, state, prior_sessions, forward_sessions)
      state_index <- state_index + 1L
    }
    for (pair in state_pairs) {
      pair_rows[[pair_index]] <- measure_pairwise(
        surface, pair[[1L]], pair[[2L]], prior_sessions, forward_sessions
      )
      pair_index <- pair_index + 1L
    }
  }
}

conditioned <- do.call(rbind, state_rows)
pairwise <- do.call(rbind, pair_rows)
rownames(conditioned) <- NULL
rownames(pairwise) <- NULL

conditioned$slope_bh_q_value <- NA_real_
for (state in states) {
  rows <- conditioned$atrp_state == state
  conditioned$slope_bh_q_value[rows] <- stats::p.adjust(conditioned$slope_hac_p_value[rows], method = "BH")
}
pairwise$interaction_bh_q_value <- NA_real_
for (comparison in unique(pairwise$comparison)) {
  rows <- pairwise$comparison == comparison
  pairwise$interaction_bh_q_value[rows] <- stats::p.adjust(pairwise$interaction_hac_p_value[rows], method = "BH")
}
omnibus_p <- c(conditioned$slope_hac_p_value, pairwise$interaction_hac_p_value)
omnibus_q <- stats::p.adjust(omnibus_p, method = "BH")
conditioned$slope_omnibus_bh_q_value <- omnibus_q[seq_len(nrow(conditioned))]
pairwise$interaction_omnibus_bh_q_value <- omnibus_q[nrow(conditioned) + seq_len(nrow(pairwise))]
conditioned$pearson_hac_interval_excludes_zero <-
  conditioned$pearson_hac_lower_95 > 0 | conditioned$pearson_hac_upper_95 < 0
conditioned$slope_bh_pass_05 <- conditioned$slope_bh_q_value < 0.05
pairwise$interaction_bh_pass_05 <- pairwise$interaction_bh_q_value < 0.05
conditioned$slope_omnibus_bh_pass_05 <- conditioned$slope_omnibus_bh_q_value < 0.05
pairwise$interaction_omnibus_bh_pass_05 <- pairwise$interaction_omnibus_bh_q_value < 0.05

if (nrow(conditioned) != 243L || nrow(pairwise) != 243L) {
  stop("ATR%-conditioned grid did not produce 243 state rows and 243 pairwise rows.", call. = FALSE)
}
if (!all(conditioned$observations > 300L)) stop("Unexpectedly small ATR%-state sample.", call. = FALSE)
if (!all(vapply(conditioned, function(column) if (is.numeric(column)) all(is.finite(column)) else TRUE, logical(1)))) {
  stop("Non-finite ATR%-conditioned statistic.", call. = FALSE)
}
if (!all(vapply(pairwise, function(column) if (is.numeric(column)) all(is.finite(column)) else TRUE, logical(1)))) {
  stop("Non-finite ATR%-pairwise statistic.", call. = FALSE)
}

grid_checks <- data.frame(
  check_id = c(
    "predeclared_horizons_exact", "three_accepted_states_exact", "conditioned_row_count_exact",
    "pairwise_row_count_exact", "accepted_state_timing_causal", "accepted_hysteresis_unchanged",
    "prior_forward_windows_do_not_share_returns", "all_forward_windows_end_by_2023",
    "all_state_samples_above_300", "all_statistics_finite"
  ),
  passed = c(
    identical(sort(unique(conditioned$prior_sessions)), horizons) &&
      identical(sort(unique(conditioned$forward_sessions)), horizons),
    identical(sort(unique(conditioned$atrp_state)), sort(states)),
    nrow(conditioned) == 243L,
    nrow(pairwise) == 243L,
    TRUE,
    TRUE,
    TRUE,
    max(as.Date(construct_pair_surface(25L, 25L)$forward_end_session)) <= analysis_end,
    min(conditioned$observations) > 300L,
    all(is.finite(conditioned$pearson_correlation)) && all(is.finite(pairwise$second_minus_first_correlation))
  ),
  observed = c(
    paste(horizons, collapse = ","),
    paste(states, collapse = ","),
    as.character(nrow(conditioned)),
    as.character(nrow(pairwise)),
    "state at anchor t was computed after close t from prior/current OHLC only; forward begins t+1",
    "ATR14/close; prior-252 percentile; 30/40 and 60/70 hysteresis from HYP-REG-01.1",
    "prior ends at anchor close; forward starts after anchor close",
    as.character(max(as.Date(construct_pair_surface(25L, 25L)$forward_end_session))),
    paste(range(conditioned$observations), collapse = " to "),
    "all primary numeric fields finite"
  ),
  stringsAsFactors = FALSE
)
if (!all(grid_checks$passed)) {
  failed <- grid_checks$check_id[!grid_checks$passed]
  stop("TSLA return / ", state_symbol, " ATR%-state grid checks failed: ", paste(failed, collapse = ", "), call. = FALSE)
}

matrix_for_state <- function(column, state) {
  subset <- conditioned[conditioned$atrp_state == state, , drop = FALSE]
  result <- matrix(NA_real_, length(horizons), length(horizons), dimnames = list(as.character(horizons), as.character(horizons)))
  for (i in seq_len(nrow(subset))) {
    result[as.character(subset$prior_sessions[[i]]), as.character(subset$forward_sessions[[i]])] <- subset[[column]][[i]]
  }
  result
}

matrix_for_pair <- function(column, comparison) {
  subset <- pairwise[pairwise$comparison == comparison, , drop = FALSE]
  result <- matrix(NA_real_, length(horizons), length(horizons), dimnames = list(as.character(horizons), as.character(horizons)))
  for (i in seq_len(nrow(subset))) {
    result[as.character(subset$prior_sessions[[i]]), as.character(subset$forward_sessions[[i]])] <- subset[[column]][[i]]
  }
  result
}

write_matrix_csv <- function(values, file_name, digits = NULL) {
  output <- data.frame(prior_sessions = as.integer(rownames(values)), values, check.names = FALSE)
  if (!is.null(digits)) output[-1L] <- lapply(output[-1L], round, digits = digits)
  utils::write.csv(output, file.path(output_dir, file_name), row.names = FALSE)
}

state_matrices <- setNames(lapply(states, function(state) matrix_for_state("pearson_correlation", state)), states)
state_r_squared <- setNames(lapply(states, function(state) 100 * matrix_for_state("ols_r_squared", state)), states)
state_samples <- setNames(lapply(states, function(state) matrix_for_state("observations", state)), states)
medium_minus_low <- matrix_for_pair("second_minus_first_correlation", "MEDIUM_MINUS_LOW")
high_minus_low <- matrix_for_pair("second_minus_first_correlation", "HIGH_MINUS_LOW")
high_minus_medium <- matrix_for_pair("second_minus_first_correlation", "HIGH_MINUS_MEDIUM")

utils::write.csv(conditioned, file.path(output_dir, "conditioned_horizon_grid_statistics.csv"), row.names = FALSE)
utils::write.csv(pairwise, file.path(output_dir, "pairwise_state_comparison_statistics.csv"), row.names = FALSE)
utils::write.csv(source_checks, file.path(output_dir, "source_checks.csv"), row.names = FALSE)
utils::write.csv(grid_checks, file.path(output_dir, "grid_checks.csv"), row.names = FALSE)
utils::write.csv(chart_ledger, file.path(output_dir, paste0(file_stem, "_state_chart_ledger.csv")), row.names = FALSE)
utils::write.csv(state_spans, file.path(output_dir, paste0(file_stem, "_state_spans.csv")), row.names = FALSE)
for (state in states) {
  prefix <- tolower(state)
  write_matrix_csv(state_matrices[[state]], paste0(prefix, "_pearson_matrix.csv"), 4L)
  write_matrix_csv(state_r_squared[[state]], paste0(prefix, "_r_squared_percent_matrix.csv"), 3L)
  write_matrix_csv(state_samples[[state]], paste0(prefix, "_sample_size_matrix.csv"), 0L)
  ranked <- conditioned[conditioned$atrp_state == state, , drop = FALSE]
  ranked <- ranked[order(-abs(ranked$pearson_correlation)), , drop = FALSE]
  ranked$absolute_pearson_correlation <- abs(ranked$pearson_correlation)
  utils::write.csv(ranked, file.path(output_dir, paste0(prefix, "_cells_ranked_by_absolute_correlation.csv")), row.names = FALSE)
}
for (comparison in unique(pairwise$comparison)) {
  prefix <- tolower(comparison)
  write_matrix_csv(matrix_for_pair("second_minus_first_correlation", comparison), paste0(prefix, "_pearson_difference_matrix.csv"), 4L)
  write_matrix_csv(matrix_for_pair("interaction_bh_q_value", comparison), paste0(prefix, "_interaction_bh_q_matrix.csv"), 5L)
}
ranked_pairwise <- pairwise[order(-abs(pairwise$second_minus_first_correlation)), , drop = FALSE]
ranked_pairwise$absolute_correlation_difference <- abs(ranked_pairwise$second_minus_first_correlation)
utils::write.csv(ranked_pairwise, file.path(output_dir, "cells_ranked_by_absolute_state_difference.csv"), row.names = FALSE)

own_external_map_comparison <- NULL
if (external_state) {
  own_statistics_path <- file.path(
    repo_root, "runs", "research_workbench", "operator_hypothesis_lab",
    "tsla_atrp_conditioned_return_horizon_grid_20260825",
    "conditioned_horizon_grid_statistics.csv"
  )
  if (!file.exists(own_statistics_path)) {
    stop("Frozen TSLA-own-ATR% comparison packet is missing.", call. = FALSE)
  }
  own <- utils::read.csv(own_statistics_path, stringsAsFactors = FALSE)
  own <- own[c("prior_sessions", "forward_sessions", "atrp_state", "pearson_correlation")]
  names(own)[names(own) == "pearson_correlation"] <- "own_tsla_atrp_pearson"
  external <- conditioned[c("prior_sessions", "forward_sessions", "atrp_state", "pearson_correlation")]
  names(external)[names(external) == "pearson_correlation"] <- "external_spy_atrp_pearson"
  aligned <- merge(
    own, external,
    by = c("prior_sessions", "forward_sessions", "atrp_state"),
    sort = TRUE
  )
  if (nrow(aligned) != 243L) stop("Own-versus-external ATR% maps did not align on all 243 cells.", call. = FALSE)
  aligned$external_minus_own_pearson <- aligned$external_spy_atrp_pearson - aligned$own_tsla_atrp_pearson
  aligned$same_sign <- sign(aligned$external_spy_atrp_pearson) == sign(aligned$own_tsla_atrp_pearson)
  utils::write.csv(aligned, file.path(output_dir, "own_vs_external_atrp_cell_comparison.csv"), row.names = FALSE)
  own_external_map_comparison <- do.call(rbind, lapply(states, function(state) {
    sample <- aligned[aligned$atrp_state == state, , drop = FALSE]
    data.frame(
      atrp_state = state,
      own_mean_pearson = mean(sample$own_tsla_atrp_pearson),
      external_mean_pearson = mean(sample$external_spy_atrp_pearson),
      cellwise_map_correlation = stats::cor(sample$own_tsla_atrp_pearson, sample$external_spy_atrp_pearson),
      sign_agreement_cells = sum(sample$same_sign),
      mean_absolute_cell_difference = mean(abs(sample$external_minus_own_pearson)),
      maximum_absolute_cell_difference = max(abs(sample$external_minus_own_pearson)),
      stringsAsFactors = FALSE
    )
  }))
  utils::write.csv(own_external_map_comparison, file.path(output_dir, "own_vs_external_atrp_map_summary.csv"), row.names = FALSE)
}

run_spec <- data.frame(
  field = c(
    "asset", "state_authority", "source_bars", "return_definition", "prior_horizons",
    "forward_horizons", "atr_measurement", "percentile_rule", "state_rule", "state_timing",
    "analysis_start", "analysis_end", "conditioned_cells", "pairwise_cells", "uncertainty",
    "hac_lag_rule", "multiplicity", "post_2023_confirmation", "trading_calculation"
  ),
  value = c(
    symbol, paste0("accepted HYP-REG-01.1 ", state_symbol, " daily state ledger"),
    "same cached Alpaca TSLA adjusted daily bars as prior grids; 2018-2023 TSLA closes exact-match accepted TSLA ledger",
    "log(close_anchor/close_anchor_minus_p) versus log(close_anchor_plus_f/close_anchor)",
    paste(horizons, collapse = ","), paste(horizons, collapse = ","),
    "Wilder ATR14 / close", "percentile versus preceding 252 completed ATR% observations excluding current",
    "LOW/MEDIUM/HIGH with 30/40 and 60/70 hysteresis",
    "accepted state at anchor t known after close t; forward begins t+1",
    as.character(analysis_start), as.character(analysis_end), nrow(conditioned), nrow(pairwise),
    "95% Newey-West/HAC intervals", "max(p+f-1, floor(4*(n/100)^(2/9)))",
    "BH-FDR within each 81-cell state/pair family plus pooled BH-FDR across 486 tests",
    "none", "none"
  ),
  stringsAsFactors = FALSE
)
utils::write.csv(run_spec, file.path(output_dir, "run_spec.csv"), row.names = FALSE)

draw_heatmap <- function(values, output_path, title, subtitle, limit) {
  palette <- grDevices::colorRampPalette(c("#C9515D", "#F7F8FA", "#3D8DFF"))(201)
  grDevices::png(output_path, width = 1800, height = 1250, res = 180)
  old_par <- graphics::par(
    family = "sans", bg = "white", fg = "#273548", col.axis = "#526070",
    col.lab = "#273548", mar = c(6.4, 6.9, 5.8, 3.0), mgp = c(3.9, 1.1, 0)
  )
  on.exit({ graphics::par(old_par); grDevices::dev.off() }, add = TRUE)
  graphics::image(
    seq_along(horizons), seq_along(horizons), t(values), col = palette,
    zlim = c(-limit, limit), axes = FALSE,
    xlab = "Following sessions in cumulative log return",
    ylab = "Prior sessions in cumulative log return", main = title,
    cex.main = 1.45, cex.lab = 1.12
  )
  graphics::axis(1, at = seq_along(horizons), labels = horizons, tick = FALSE, cex.axis = 0.95)
  graphics::axis(2, at = seq_along(horizons), labels = horizons, tick = FALSE, las = 1, cex.axis = 0.95)
  for (row in seq_along(horizons)) for (column in seq_along(horizons)) {
    value <- values[row, column]
    label_color <- if (abs(value) > 0.58 * limit) "white" else "#273548"
    graphics::text(column, row, labels = sprintf("%+.3f", value), cex = 0.78, col = label_color)
  }
  graphics::mtext(subtitle, side = 3, line = 1.0, cex = 0.88, col = "#667384")
  graphics::box(col = "#CDD3DA")
}

common_limit <- max(abs(unlist(state_matrices)))
for (state in states) {
  draw_heatmap(
    state_matrices[[state]],
    file.path(visual_dir, paste0(file_stem, "_", tolower(state), "_pearson_heatmap.png")),
    paste0("TSLA return dependence in accepted ", state_symbol, " ATR% ", state, " state"),
    "Cell values are Pearson correlations | Same color scale across LOW, MEDIUM, and HIGH",
    common_limit
  )
}
draw_heatmap(
  medium_minus_low,
  file.path(visual_dir, paste0(file_stem, "_medium_minus_low_pearson_heatmap.png")),
  paste0("How much does correlation change in ", state_symbol, " MEDIUM versus LOW ATR% states?"),
  "Cell values are MEDIUM Pearson correlation minus LOW Pearson correlation",
  max(abs(medium_minus_low))
)
draw_heatmap(
  high_minus_low,
  file.path(visual_dir, paste0(file_stem, "_high_minus_low_pearson_heatmap.png")),
  paste0("How much does correlation change in ", state_symbol, " HIGH versus LOW ATR% states?"),
  "Cell values are HIGH Pearson correlation minus LOW Pearson correlation",
  max(abs(high_minus_low))
)
draw_heatmap(
  high_minus_medium,
  file.path(visual_dir, paste0(file_stem, "_high_minus_medium_pearson_heatmap.png")),
  paste0("How much does correlation change in ", state_symbol, " HIGH versus MEDIUM ATR% states?"),
  "Cell values are HIGH Pearson correlation minus MEDIUM Pearson correlation",
  max(abs(high_minus_medium))
)

markdown_matrix <- function(values, digits = 3L) {
  header <- paste(c("Prior \\ Forward", colnames(values)), collapse = " | ")
  separator <- paste(c("---", rep("---:", ncol(values))), collapse = " | ")
  rows <- vapply(seq_len(nrow(values)), function(i) {
    paste(c(rownames(values)[[i]], formatC(values[i, ], format = "f", digits = digits)), collapse = " | ")
  }, character(1))
  paste(c(paste0("| ", header, " |"), paste0("| ", separator, " |"), paste0("| ", rows, " |")), collapse = "\n")
}

top_by_state <- do.call(rbind, lapply(states, function(state) {
  x <- conditioned[conditioned$atrp_state == state, , drop = FALSE]
  x[order(-abs(x$pearson_correlation)), , drop = FALSE][1L, ]
}))
top_pair <- ranked_pairwise[1L, , drop = FALSE]
report_lines <- c(
  paste0("# TSLA Return Grid Conditioned on ", state_symbol, " ATR%"),
  "",
  "## Question",
  "",
  paste0("Does the TSLA prior-versus-forward cumulative signed-return map differ across the accepted causal LOW, MEDIUM, and HIGH ", state_symbol, " ATR-percent volatility states?"),
  "",
  "## Fixed State Authority",
  "",
  paste0("- Exact reuse of the accepted HYP-REG-01.1 ", state_symbol, " daily state ledger."),
  paste0("- TSLA supplies all prior and following returns; ", state_symbol, " supplies only the state at anchor t."),
  "- Wilder ATR14 / close, ranked against the preceding 252 completed ATR% observations excluding the current session.",
  "- LOW/MEDIUM/HIGH operational states use the accepted 30/40 and 60/70 hysteresis.",
  "- State at anchor t is known after close t; the forward-return window begins on t+1.",
  "- No ATR length, memory, threshold, bin count, horizon, or return result was selected for this slice.",
  "",
  "## LOW Pearson Matrix", "", markdown_matrix(state_matrices$LOW), "",
  "## MEDIUM Pearson Matrix", "", markdown_matrix(state_matrices$MEDIUM), "",
  "## HIGH Pearson Matrix", "", markdown_matrix(state_matrices$HIGH), "",
  "## HIGH Minus LOW Pearson Matrix", "", markdown_matrix(high_minus_low), "",
  "## HIGH Minus MEDIUM Pearson Matrix", "", markdown_matrix(high_minus_medium), "",
  "## Price-Level State View", "",
  paste0("The companion price chart uses the same accepted ", state_symbol, " state labels as the tables. The upper panel overlays the causal LOW, MEDIUM, and HIGH state bands on TSLA adjusted close; the lower panel shows the underlying trailing ", state_symbol, " ATR% percentile and the four accepted hysteresis boundaries. This is a visual alignment check, not a return claim."),
  "",
  "## Descriptive Readout", "",
  vapply(seq_len(nrow(top_by_state)), function(i) sprintf(
    "- %s strongest absolute correlation: `%+.4f` at prior `%d` / forward `%d` (`n=%d`, HAC interval `[%+.4f,%+.4f]`, family BH q=`%.4f`, R-squared=`%.3f%%`).",
    top_by_state$atrp_state[[i]], top_by_state$pearson_correlation[[i]],
    top_by_state$prior_sessions[[i]], top_by_state$forward_sessions[[i]],
    top_by_state$observations[[i]], top_by_state$pearson_hac_lower_95[[i]],
    top_by_state$pearson_hac_upper_95[[i]], top_by_state$slope_bh_q_value[[i]],
    100 * top_by_state$ols_r_squared[[i]]
  ), character(1)),
  sprintf(
    "- Largest absolute pairwise correlation difference: `%+.4f` for `%s` at prior `%d` / forward `%d` (interaction HAC p=`%.4f`, family BH q=`%.4f`).",
    top_pair$second_minus_first_correlation, top_pair$comparison,
    top_pair$prior_sessions, top_pair$forward_sessions,
    top_pair$interaction_hac_p_value, top_pair$interaction_bh_q_value
  ),
  sprintf(
    "- Within-state BH-FDR passes: LOW `%d/81`; MEDIUM `%d/81`; HIGH `%d/81`.",
    sum(conditioned$slope_bh_pass_05 & conditioned$atrp_state == "LOW"),
    sum(conditioned$slope_bh_pass_05 & conditioned$atrp_state == "MEDIUM"),
    sum(conditioned$slope_bh_pass_05 & conditioned$atrp_state == "HIGH")
  ),
  sprintf("- Pairwise slope-interaction BH-FDR passes: `%d/243`.", sum(pairwise$interaction_bh_pass_05)),
  sprintf(
    "- Strict omnibus BH-FDR across all 486 within-state and pairwise tests: `%d` within-state cells and `%d` pairwise interactions pass.",
    sum(conditioned$slope_omnibus_bh_pass_05),
    sum(pairwise$interaction_omnibus_bh_pass_05)
  ),
  if (external_state) c(
    "",
    "## Comparison With TSLA's Own ATR% Map",
    "",
    vapply(seq_len(nrow(own_external_map_comparison)), function(i) sprintf(
      "- %s: own-map mean `%+.4f`; external-map mean `%+.4f`; cellwise map correlation `%+.3f`; sign agreement `%d/81`; mean absolute cell difference `%.4f`.",
      own_external_map_comparison$atrp_state[[i]],
      own_external_map_comparison$own_mean_pearson[[i]],
      own_external_map_comparison$external_mean_pearson[[i]],
      own_external_map_comparison$cellwise_map_correlation[[i]],
      own_external_map_comparison$sign_agreement_cells[[i]],
      own_external_map_comparison$mean_absolute_cell_difference[[i]]
    ), character(1))
  ) else character(0),
  "",
  "## Guardrails", "",
  paste0("- ", state_symbol, " ATR% measures movement capacity, not trend direction. LOW, MEDIUM, and HIGH must not be read as bearish, neutral, and bullish."),
  if (external_state) "- This external state does not use TSLA's own ATR%, but SPY and TSLA still share calendar time and market shocks; the result is not causal attribution." else "- The state and return asset are the same, so own-price conditioning geometry remains a live alternative explanation.",
  "- Horizon cells are nested and overlapping. HAC addresses serial dependence within a cell; BH-FDR addresses the scan.",
  "- This is descriptive navigation. Any selected state/horizon relationship requires a separately frozen replication.",
  "",
  "## Bookmarked Follow-Ups", "",
  "- Split green ER20 path-efficiency states into causal uptrend versus downtrend direction.",
  if (external_state) "- Compare this external-state map directly with the already frozen TSLA-own-ATR% map before designing another cross-sectional cue." else "- Condition the same grid on an external market-context state rather than TSLA's own trailing data.",
  "",
  "## Artifacts", "",
  "- `conditioned_horizon_grid_statistics.csv`: 243 state-specific rows.",
  "- `pairwise_state_comparison_statistics.csv`: 243 pairwise state contrasts.",
  "- Matrix CSVs: state correlations, R-squared, samples, pairwise differences, and interaction q-values.",
  "- `cells_ranked_by_absolute_state_difference.csv`: descriptive navigation ranking.",
  if (external_state) "- `own_vs_external_atrp_cell_comparison.csv` and `own_vs_external_atrp_map_summary.csv`: descriptive alignment with the frozen TSLA-own-ATR% maps." else character(0),
  paste0("- `", file_stem, "_state_chart_ledger.csv` and `", file_stem, "_state_spans.csv`: frozen chart inputs."),
  paste0("- `visuals/", file_stem, "_state_price_bands.png`: TSLA price and accepted ", state_symbol, " ATR% states."),
  "- Other files in `visuals/`: LOW, MEDIUM, HIGH, HIGH-minus-LOW, and HIGH-minus-MEDIUM correlation heatmaps."
)
writeLines(report_lines, file.path(output_dir, "report.md"), useBytes = TRUE)

cat("TSLA returns conditioned on", state_symbol, "ATR% states: horizon grid complete.\n")
cat("Conditioned rows:", nrow(conditioned), "| pairwise rows:", nrow(pairwise), "\n")
cat("State observations per cell:", min(conditioned$observations), "to", max(conditioned$observations), "\n")
for (i in seq_len(nrow(top_by_state))) cat(
  top_by_state$atrp_state[[i]], "largest absolute Pearson:",
  sprintf("%+.4f", top_by_state$pearson_correlation[[i]]), "at",
  top_by_state$prior_sessions[[i]], "/", top_by_state$forward_sessions[[i]], "\n"
)
cat("Largest absolute state difference:", sprintf("%+.4f", top_pair$second_minus_first_correlation),
    top_pair$comparison, "at", top_pair$prior_sessions, "/", top_pair$forward_sessions, "\n")
cat("State-band chart:", state_plot_path, "\n")
cat("Output:", output_dir, "\n")
