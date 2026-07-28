# Gen5 S0 statistical-arbitrage admissibility POC helpers.
# Research only: historical convergence is not historical borrow executability.

g5_s0_schema_version <- function() {
  "gen5_s0_statistical_arbitrage_admissibility_v0.1"
}

g5_s0_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message)
  stop(message, call. = FALSE)
}

g5_s0_universe <- function() {
  data.frame(
    symbol = c(
      "XLB", "XLC", "XLE", "XLF", "XLI", "XLK", "XLP", "XLRE", "XLU", "XLV", "XLY",
      "IWB", "IWM", "IWD", "IWF", "IWN", "IWO", "MDY", "IJR",
      "EWA", "EWC", "EWG", "EWH", "EWI", "EWJ", "EWL", "EWN", "EWS", "EWU",
      "EEM", "EWT", "EWY", "EWW", "EWZ", "FXI", "INDA", "TUR"
    ),
    economic_group = c(
      rep("us_sector", 11L),
      rep("us_size_style", 8L),
      rep("developed_country", 10L),
      rep("emerging_country", 8L)
    ),
    stringsAsFactors = FALSE
  )
}

g5_s0_contract <- function() {
  list(
    universe = g5_s0_universe(),
    reference_symbol = "XLB",
    train_sessions = 504L,
    minimum_train_bars = 480L,
    recent_sessions = 63L,
    minimum_adjusted_close = 10,
    minimum_median_dollar_volume = 25e6,
    minimum_return_correlation = 0.60,
    minimum_beta = 0.25,
    maximum_beta = 4.00,
    maximum_relative_beta_drift = 0.50,
    minimum_half_life = 2,
    maximum_half_life = 30,
    maximum_pairs_per_group = 3L,
    event_z_threshold = 2.00,
    quiet_z_threshold = 0.50,
    embargo_sessions = 20L,
    horizons = c(5L, 10L, 20L),
    primary_horizon = 10L,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    random_policy_count = 2000L,
    random_seed = 5403L,
    non_event_seed = 5404L,
    random_percentile = 0.90,
    minimum_pairs = 8L,
    minimum_groups = 3L,
    pair_breadth_quarters = 10L,
    minimum_events = 120L,
    minimum_pairs_with_five_events = 8L,
    positive_quarters = 8L,
    minimum_control_match = 0.80,
    group_contribution_cap = 0.50,
    pair_contribution_cap = 0.20,
    year_contribution_cap = 0.50,
    minimum_relationship_survival = 0.60,
    minimum_quarter_survival = 0.40,
    oos_start = as.Date("2018-01-01"),
    development_end = as.Date("2021-12-31"),
    confirmation_start = as.Date("2022-01-01"),
    confirmation_end = as.Date("2024-12-31"),
    shadow_start = as.Date("2025-01-01"),
    oos_end = as.Date("2026-06-30"),
    query_start = as.Date("2016-01-01"),
    query_end = as.Date("2026-07-24"),
    as_of_timestamp = "2026-07-24 17:30:00",
    decision_time = "17:30 America/New_York"
  )
}

g5_s0_validate_contract <- function(contract) {
  required <- c(
    "universe", "reference_symbol", "train_sessions", "minimum_train_bars",
    "recent_sessions", "minimum_adjusted_close",
    "minimum_median_dollar_volume", "minimum_return_correlation",
    "minimum_beta", "maximum_beta", "maximum_relative_beta_drift",
    "minimum_half_life", "maximum_half_life", "maximum_pairs_per_group",
    "event_z_threshold", "quiet_z_threshold", "embargo_sessions", "horizons",
    "primary_horizon", "primary_cost_bps", "stress_cost_bps",
    "random_policy_count", "random_seed", "non_event_seed",
    "random_percentile", "minimum_pairs", "minimum_groups",
    "pair_breadth_quarters", "minimum_events",
    "minimum_pairs_with_five_events", "positive_quarters",
    "minimum_control_match", "group_contribution_cap",
    "pair_contribution_cap", "year_contribution_cap",
    "minimum_relationship_survival", "minimum_quarter_survival",
    "oos_start", "development_end", "confirmation_start",
    "confirmation_end", "shadow_start", "oos_end", "query_start",
    "query_end", "as_of_timestamp", "decision_time"
  )
  missing <- setdiff(required, names(contract))
  if (length(missing)) {
    g5_s0_stop(paste("S0 contract is missing:", paste(missing, collapse = ", ")))
  }
  if (!is.data.frame(contract$universe) ||
      !all(c("symbol", "economic_group") %in% names(contract$universe))) {
    g5_s0_stop("S0 universe must contain symbol and economic_group.")
  }
  contract$universe$symbol <- toupper(as.character(contract$universe$symbol))
  contract$universe$economic_group <- as.character(contract$universe$economic_group)
  if (nrow(contract$universe) != 37L ||
      length(unique(contract$universe$symbol)) != 37L) {
    g5_s0_stop("S0 requires exactly thirty-seven unique ETFs.")
  }
  expected <- c(
    developed_country = 10L,
    emerging_country = 8L,
    us_sector = 11L,
    us_size_style = 8L
  )
  actual <- table(contract$universe$economic_group)
  if (!identical(as.integer(actual[names(expected)]), as.integer(expected))) {
    g5_s0_stop("S0 economic-group counts must remain 10, 8, 11, and 8.")
  }
  fixed <- list(
    train_sessions = 504L,
    minimum_train_bars = 480L,
    maximum_pairs_per_group = 3L,
    embargo_sessions = 20L,
    primary_horizon = 10L,
    random_policy_count = 2000L,
    random_seed = 5403L,
    non_event_seed = 5404L
  )
  for (name in names(fixed)) {
    if (!identical(as.integer(contract[[name]]), fixed[[name]])) {
      g5_s0_stop(paste("S0 frozen integer changed:", name))
    }
  }
  if (!identical(sort(as.integer(contract$horizons)), c(5L, 10L, 20L)) ||
      !isTRUE(all.equal(as.numeric(contract$event_z_threshold), 2)) ||
      !isTRUE(all.equal(as.numeric(contract$quiet_z_threshold), 0.5)) ||
      !isTRUE(all.equal(as.numeric(contract$primary_cost_bps), 5)) ||
      !isTRUE(all.equal(as.numeric(contract$stress_cost_bps), 10)) ||
      !isTRUE(all.equal(as.numeric(contract$random_percentile), 0.9))) {
    g5_s0_stop("S0 frozen horizons, thresholds, costs, or random percentile changed.")
  }
  contract
}

g5_s0_required_symbols <- function(contract = g5_s0_contract()) {
  contract <- g5_s0_validate_contract(contract)
  contract$universe$symbol
}

g5_s0_validate_bars <- function(bars, contract = g5_s0_contract()) {
  contract <- g5_s0_validate_contract(contract)
  if (!is.data.frame(bars) || !nrow(bars)) {
    g5_s0_stop("S0 requires a non-empty adjusted daily bar table.")
  }
  if (exists("g5_validate_bar_data", mode = "function")) {
    bars <- g5_validate_bar_data(bars)
  }
  required <- c("symbol", "session_date", "open", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_s0_stop(paste("S0 bars are missing:", paste(missing, collapse = ", ")))
  }
  bars$symbol <- toupper(as.character(bars$symbol))
  bars$session_date <- as.Date(bars$session_date)
  bars$open <- as.numeric(bars$open)
  bars$close <- as.numeric(bars$close)
  bars$volume <- as.numeric(bars$volume)
  if (any(is.na(bars$session_date)) ||
      any(!is.finite(bars$open) | bars$open <= 0) ||
      any(!is.finite(bars$close) | bars$close <= 0) ||
      any(!is.finite(bars$volume) | bars$volume < 0)) {
    g5_s0_stop("S0 bars contain invalid dates, prices, or volume.")
  }
  if (anyDuplicated(paste(bars$symbol, bars$session_date))) {
    g5_s0_stop("S0 bars contain duplicate symbol/session rows.")
  }
  missing_symbols <- setdiff(g5_s0_required_symbols(contract), unique(bars$symbol))
  if (length(missing_symbols)) {
    g5_s0_stop(paste("S0 bars are missing symbols:", paste(missing_symbols, collapse = ", ")))
  }
  bars <- bars[bars$symbol %in% g5_s0_required_symbols(contract), , drop = FALSE]
  bars[order(bars$symbol, bars$session_date), , drop = FALSE]
}

g5_s0_quarter_id <- function(date) {
  date <- as.Date(date)
  paste0(format(date, "%Y"), "Q", (as.integer(format(date, "%m")) - 1L) %/% 3L + 1L)
}

g5_s0_period_id <- function(date, contract = g5_s0_contract()) {
  date <- as.Date(date)
  ifelse(
    date <= contract$development_end,
    "development_2018_2021",
    ifelse(
      date >= contract$confirmation_start & date <= contract$confirmation_end,
      "confirmation_2022_2024",
      ifelse(date >= contract$shadow_start, "historical_shadow_2025_2026", "outside_contract")
    )
  )
}

g5_s0_reference_sessions <- function(bars, contract = g5_s0_contract()) {
  sessions <- sort(unique(as.Date(
    bars$session_date[bars$symbol == contract$reference_symbol]
  )))
  sessions <- sessions[sessions >= contract$query_start & sessions <= contract$query_end]
  if (!length(sessions)) g5_s0_stop("S0 reference symbol supplied no sessions.")
  sessions
}

g5_s0_schedule <- function(bars, contract = g5_s0_contract()) {
  contract <- g5_s0_validate_contract(contract)
  bars <- g5_s0_validate_bars(bars, contract)
  sessions <- g5_s0_reference_sessions(bars, contract)
  starts <- seq(contract$oos_start, as.Date("2026-04-01"), by = "3 months")
  rows <- lapply(seq_along(starts), function(i) {
    oos_start <- starts[[i]]
    next_start <- if (i < length(starts)) starts[[i + 1L]] else as.Date("2026-07-01")
    prior <- sessions[sessions < oos_start]
    if (!length(prior)) return(NULL)
    formation <- max(prior)
    train <- tail(prior, contract$train_sessions)
    data.frame(
      fold_id = g5_s0_quarter_id(oos_start),
      formation_date = formation,
      train_start_date = if (length(train)) min(train) else as.Date(NA),
      train_session_count = length(train),
      oos_start = oos_start,
      oos_end = next_start - 1,
      evaluation_period = g5_s0_period_id(oos_start, contract),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows[!vapply(rows, is.null, logical(1L))])
}

g5_s0_symbol_indexes <- function(bars) {
  ordered <- bars[order(bars$symbol, bars$session_date), , drop = FALSE]
  split(ordered, ordered$symbol)
}

g5_s0_symbol_eligibility <- function(
  bars,
  schedule,
  contract = g5_s0_contract()
) {
  contract <- g5_s0_validate_contract(contract)
  sessions <- g5_s0_reference_sessions(bars, contract)
  by_symbol <- g5_s0_symbol_indexes(bars)
  rows <- list()
  for (fold_i in seq_len(nrow(schedule))) {
    formation <- schedule$formation_date[[fold_i]]
    train_sessions <- tail(sessions[sessions <= formation], contract$train_sessions)
    recent <- tail(train_sessions, contract$recent_sessions)
    for (u_i in seq_len(nrow(contract$universe))) {
      symbol <- contract$universe$symbol[[u_i]]
      x <- by_symbol[[symbol]]
      train_x <- x[x$session_date %in% train_sessions, , drop = FALSE]
      recent_x <- x[x$session_date %in% recent, , drop = FALSE]
      formation_close <- x$close[x$session_date == formation]
      formation_close <- if (length(formation_close)) formation_close[[1L]] else NA_real_
      median_dv <- if (nrow(recent_x)) {
        stats::median(recent_x$close * recent_x$volume)
      } else {
        NA_real_
      }
      history_ok <- length(train_sessions) == contract$train_sessions &&
        nrow(train_x) >= contract$minimum_train_bars
      freshness_ok <- length(recent) == contract$recent_sessions &&
        nrow(recent_x) >= contract$recent_sessions - 3L &&
        formation %in% train_x$session_date
      price_ok <- is.finite(formation_close) &&
        formation_close >= contract$minimum_adjusted_close
      liquidity_ok <- is.finite(median_dv) &&
        median_dv >= contract$minimum_median_dollar_volume
      rows[[length(rows) + 1L]] <- data.frame(
        schema_version = g5_s0_schema_version(),
        fold_id = schedule$fold_id[[fold_i]],
        formation_date = formation,
        evaluation_period = schedule$evaluation_period[[fold_i]],
        symbol = symbol,
        economic_group = contract$universe$economic_group[[u_i]],
        train_reference_sessions = length(train_sessions),
        train_observed_sessions = nrow(train_x),
        recent_observed_sessions = nrow(recent_x),
        formation_close = formation_close,
        median_dollar_volume_63 = median_dv,
        history_ok = history_ok,
        freshness_ok = freshness_ok,
        price_ok = price_ok,
        liquidity_ok = liquidity_ok,
        eligible = history_ok && freshness_ok && price_ok && liquidity_ok,
        stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

g5_s0_pair_fit <- function(
  bars_a,
  bars_b,
  train_sessions,
  contract = g5_s0_contract()
) {
  a <- bars_a[bars_a$session_date %in% train_sessions, c("session_date", "close"), drop = FALSE]
  b <- bars_b[bars_b$session_date %in% train_sessions, c("session_date", "close"), drop = FALSE]
  names(a)[[2L]] <- "close_a"
  names(b)[[2L]] <- "close_b"
  x <- merge(a, b, by = "session_date", all = FALSE)
  x <- x[is.finite(x$close_a) & is.finite(x$close_b), , drop = FALSE]
  if (nrow(x) < contract$minimum_train_bars) return(NULL)
  log_a <- log(x$close_a)
  log_b <- log(x$close_b)
  ret_corr <- suppressWarnings(stats::cor(diff(log_a), diff(log_b)))
  fit <- stats::lm(log_a ~ log_b)
  alpha <- unname(stats::coef(fit)[[1L]])
  beta <- unname(stats::coef(fit)[[2L]])
  residual <- unname(stats::residuals(fit))
  half <- floor(nrow(x) / 2)
  beta_first <- unname(stats::coef(stats::lm(log_a[seq_len(half)] ~ log_b[seq_len(half)]))[[2L]])
  second_i <- (half + 1L):nrow(x)
  beta_second <- unname(stats::coef(stats::lm(log_a[second_i] ~ log_b[second_i]))[[2L]])
  beta_drift <- if (is.finite(beta) && abs(beta) > 0) {
    abs(beta_second - beta_first) / abs(beta)
  } else {
    Inf
  }
  ar_fit <- stats::lm(residual[-1L] ~ residual[-length(residual)])
  phi <- unname(stats::coef(ar_fit)[[2L]])
  half_life <- if (is.finite(phi) && phi > 0 && phi < 1) {
    log(0.5) / log(phi)
  } else {
    NA_real_
  }
  n <- length(residual)
  dy <- residual[3:n] - residual[2:(n - 1L)]
  lag_level <- residual[2:(n - 1L)]
  lag_delta <- residual[2:(n - 1L)] - residual[1:(n - 2L)]
  adf_fit <- stats::lm(dy ~ 0 + lag_level + lag_delta)
  adf_summary <- summary(adf_fit)$coefficients
  gamma_t <- if ("lag_level" %in% rownames(adf_summary)) {
    adf_summary["lag_level", "t value"]
  } else {
    NA_real_
  }
  residual_sd <- stats::sd(residual)
  structural <- all(c(
    is.finite(ret_corr) && ret_corr >= contract$minimum_return_correlation,
    is.finite(beta) && beta >= contract$minimum_beta && beta <= contract$maximum_beta,
    is.finite(beta_drift) && beta_drift <= contract$maximum_relative_beta_drift,
    is.finite(phi) && phi > 0 && phi < 1,
    is.finite(half_life) && half_life >= contract$minimum_half_life &&
      half_life <= contract$maximum_half_life,
    is.finite(residual_sd) && residual_sd > 0,
    is.finite(gamma_t)
  ))
  list(
    train_observations = nrow(x),
    alpha = alpha,
    beta = beta,
    beta_first = beta_first,
    beta_second = beta_second,
    relative_beta_drift = beta_drift,
    return_correlation = ret_corr,
    residual_phi = phi,
    half_life = half_life,
    residual_mean = mean(residual),
    residual_sd = residual_sd,
    gamma_t = gamma_t,
    structural_eligible = structural
  )
}

g5_s0_build_pair_fits <- function(
  bars,
  schedule,
  symbol_eligibility,
  contract = g5_s0_contract()
) {
  contract <- g5_s0_validate_contract(contract)
  sessions <- g5_s0_reference_sessions(bars, contract)
  by_symbol <- g5_s0_symbol_indexes(bars)
  rows <- list()
  for (fold_i in seq_len(nrow(schedule))) {
    fold <- schedule[fold_i, , drop = FALSE]
    train <- tail(sessions[sessions <= fold$formation_date], contract$train_sessions)
    eligible <- symbol_eligibility[
      symbol_eligibility$fold_id == fold$fold_id & symbol_eligibility$eligible,
      ,
      drop = FALSE
    ]
    for (group in unique(contract$universe$economic_group)) {
      symbols <- sort(eligible$symbol[eligible$economic_group == group])
      if (length(symbols) < 2L) next
      pairs <- utils::combn(symbols, 2L)
      for (pair_i in seq_len(ncol(pairs))) {
        symbol_a <- pairs[1L, pair_i]
        symbol_b <- pairs[2L, pair_i]
        fit <- g5_s0_pair_fit(
          by_symbol[[symbol_a]], by_symbol[[symbol_b]], train, contract
        )
        if (is.null(fit)) next
        rows[[length(rows) + 1L]] <- data.frame(
          schema_version = g5_s0_schema_version(),
          fold_id = fold$fold_id,
          formation_date = fold$formation_date,
          oos_start = fold$oos_start,
          oos_end = fold$oos_end,
          evaluation_period = fold$evaluation_period,
          economic_group = group,
          symbol_a = symbol_a,
          symbol_b = symbol_b,
          pair_id = paste(symbol_a, symbol_b, sep = "~"),
          train_observations = fit$train_observations,
          alpha = fit$alpha,
          beta = fit$beta,
          beta_first = fit$beta_first,
          beta_second = fit$beta_second,
          relative_beta_drift = fit$relative_beta_drift,
          return_correlation = fit$return_correlation,
          residual_phi = fit$residual_phi,
          half_life = fit$half_life,
          residual_mean = fit$residual_mean,
          residual_sd = fit$residual_sd,
          gamma_t = fit$gamma_t,
          structural_eligible = fit$structural_eligible,
          selected = FALSE,
          selection_rank = NA_integer_,
          stringsAsFactors = FALSE
        )
      }
    }
  }
  out <- do.call(rbind, rows)
  if (is.null(out) || !nrow(out)) g5_s0_stop("S0 produced no pair fits.")
  for (fold in unique(out$fold_id)) {
    for (group in unique(out$economic_group)) {
      idx <- which(
        out$fold_id == fold &
          out$economic_group == group &
          out$structural_eligible
      )
      if (!length(idx)) next
      idx <- idx[order(out$gamma_t[idx], out$pair_id[idx])]
      used <- character()
      rank_i <- 0L
      for (row_i in idx) {
        if (out$symbol_a[[row_i]] %in% used || out$symbol_b[[row_i]] %in% used) next
        rank_i <- rank_i + 1L
        out$selected[[row_i]] <- TRUE
        out$selection_rank[[row_i]] <- rank_i
        used <- c(used, out$symbol_a[[row_i]], out$symbol_b[[row_i]])
        if (rank_i >= contract$maximum_pairs_per_group) break
      }
    }
  }
  out[order(out$formation_date, out$economic_group, out$gamma_t, out$pair_id), , drop = FALSE]
}

g5_s0_opportunity_table <- function(
  bars,
  pair_fits,
  contract = g5_s0_contract()
) {
  sessions <- g5_s0_reference_sessions(bars, contract)
  session_index <- setNames(seq_along(sessions), as.character(sessions))
  by_symbol <- g5_s0_symbol_indexes(bars)
  named_value <- function(x, column) {
    value <- as.numeric(x[[column]])
    names(value) <- as.character(x$session_date)
    value
  }
  close_index <- lapply(by_symbol, named_value, column = "close")
  open_index <- lapply(by_symbol, named_value, column = "open")
  rows <- list()
  eligible_fits <- pair_fits[pair_fits$structural_eligible, , drop = FALSE]
  for (fit_i in seq_len(nrow(eligible_fits))) {
    fit <- eligible_fits[fit_i, , drop = FALSE]
    oos <- sessions[sessions >= fit$oos_start & sessions <= fit$oos_end]
    a_close <- close_index[[fit$symbol_a]]
    b_close <- close_index[[fit$symbol_b]]
    a_open <- open_index[[fit$symbol_a]]
    b_open <- open_index[[fit$symbol_b]]
    for (signal_i in seq_along(oos)) {
      signal_date <- oos[[signal_i]]
      idx <- match(signal_date, sessions)
      if (is.na(idx) || idx + 1L + max(contract$horizons) > length(sessions)) next
      entry_date <- sessions[[idx + 1L]]
      endpoint_dates <- sessions[idx + 1L + contract$horizons]
      required_dates <- c(signal_date, entry_date, endpoint_dates)
      prices <- c(
        a_close[as.character(signal_date)],
        b_close[as.character(signal_date)],
        a_open[as.character(entry_date)],
        b_open[as.character(entry_date)],
        a_open[as.character(endpoint_dates)],
        b_open[as.character(endpoint_dates)]
      )
      if (any(!is.finite(prices))) next
      residual <- log(a_close[[as.character(signal_date)]]) -
        fit$alpha - fit$beta * log(b_close[[as.character(signal_date)]])
      z <- (residual - fit$residual_mean) / fit$residual_sd
      row <- data.frame(
        schema_version = g5_s0_schema_version(),
        fold_id = fit$fold_id,
        formation_date = fit$formation_date,
        evaluation_period = fit$evaluation_period,
        economic_group = fit$economic_group,
        pair_id = fit$pair_id,
        symbol_a = fit$symbol_a,
        symbol_b = fit$symbol_b,
        selected_pair = fit$selected,
        alpha = fit$alpha,
        beta = fit$beta,
        signal_date = signal_date,
        signal_session_index = idx,
        entry_date = entry_date,
        entry_session_index = idx + 1L,
        endpoint_5 = endpoint_dates[[1L]],
        endpoint_10 = endpoint_dates[[2L]],
        endpoint_20 = endpoint_dates[[3L]],
        endpoint_20_session_index = idx + 1L + max(contract$horizons),
        z = z,
        stringsAsFactors = FALSE
      )
      for (h_i in seq_along(contract$horizons)) {
        h <- contract$horizons[[h_i]]
        row[[paste0("return_a_", h)]] <-
          a_open[[as.character(endpoint_dates[[h_i]])]] /
          a_open[[as.character(entry_date)]] - 1
        row[[paste0("return_b_", h)]] <-
          b_open[[as.character(endpoint_dates[[h_i]])]] /
          b_open[[as.character(entry_date)]] - 1
      }
      rows[[length(rows) + 1L]] <- row
    }
  }
  out <- do.call(rbind, rows)
  if (is.null(out) || !nrow(out)) g5_s0_stop("S0 produced no OOS opportunities.")
  out[order(out$fold_id, out$pair_id, out$signal_date), , drop = FALSE]
}

g5_s0_add_fade_returns <- function(
  rows,
  direction,
  contract = g5_s0_contract()
) {
  direction <- as.numeric(direction)
  if (length(direction) == 1L) direction <- rep(direction, nrow(rows))
  rows$fade_direction <- direction
  rows$weight_a <- -direction / (1 + abs(rows$beta))
  rows$weight_b <- direction * rows$beta / (1 + abs(rows$beta))
  for (h in contract$horizons) {
    gross <- rows$weight_a * rows[[paste0("return_a_", h)]] +
      rows$weight_b * rows[[paste0("return_b_", h)]]
    rows[[paste0("gross_", h)]] <- gross
    rows[[paste0("net_", h, "_5bp")]] <-
      gross - 2 * contract$primary_cost_bps / 10000
    rows[[paste0("net_", h, "_10bp")]] <-
      gross - 2 * contract$stress_cost_bps / 10000
  }
  rows
}

g5_s0_event_table <- function(
  opportunities,
  contract = g5_s0_contract()
) {
  candidates <- opportunities[
    is.finite(opportunities$z) &
      abs(opportunities$z) >= contract$event_z_threshold,
    ,
    drop = FALSE
  ]
  pieces <- split(candidates, interaction(candidates$fold_id, candidates$pair_id, drop = TRUE))
  accepted <- lapply(pieces, function(part) {
    part <- part[order(part$signal_session_index), , drop = FALSE]
    keep <- logical(nrow(part))
    last_endpoint <- -Inf
    for (i in seq_len(nrow(part))) {
      if (part$signal_session_index[[i]] < last_endpoint) next
      keep[[i]] <- TRUE
      last_endpoint <- part$endpoint_20_session_index[[i]]
    }
    part[keep, , drop = FALSE]
  })
  out <- do.call(rbind, accepted)
  if (is.null(out)) out <- candidates[0, , drop = FALSE]
  out <- g5_s0_add_fade_returns(out, sign(out$z), contract)
  rownames(out) <- NULL
  out
}

g5_s0_pair_means <- function(events, pair_fits, contract = g5_s0_contract()) {
  keys <- unique(pair_fits[pair_fits$structural_eligible, c(
    "fold_id", "evaluation_period", "economic_group", "pair_id", "selected"
  )])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    key <- keys[i, , drop = FALSE]
    x <- events[events$fold_id == key$fold_id & events$pair_id == key$pair_id, , drop = FALSE]
    row <- key
    row$event_count <- nrow(x)
    for (h in contract$horizons) {
      for (cost in c("5bp", "10bp")) {
        column <- paste0("net_", h, "_", cost)
        row[[column]] <- if (nrow(x)) mean(x[[column]]) else NA_real_
      }
      gross_column <- paste0("gross_", h)
      row[[gross_column]] <- if (nrow(x)) mean(x[[gross_column]]) else NA_real_
    }
    row
  })
  do.call(rbind, rows)
}

g5_s0_quarter_summary <- function(
  pair_means,
  pair_fits,
  selected_only = TRUE,
  contract = g5_s0_contract()
) {
  fits <- pair_fits[pair_fits$structural_eligible, , drop = FALSE]
  if (selected_only) fits <- fits[fits$selected, , drop = FALSE]
  rows <- lapply(unique(fits$fold_id), function(fold) {
    selected <- fits[fits$fold_id == fold, , drop = FALSE]
    means <- pair_means[
      pair_means$fold_id == fold &
        pair_means$pair_id %in% selected$pair_id,
      ,
      drop = FALSE
    ]
    active <- means[means$event_count > 0, , drop = FALSE]
    data.frame(
      schema_version = g5_s0_schema_version(),
      fold_id = fold,
      evaluation_period = selected$evaluation_period[[1L]],
      calendar_year = as.integer(substr(fold, 1, 4)),
      selected_pair_count = nrow(selected),
      selected_group_count = length(unique(selected$economic_group)),
      active_pair_count = nrow(active),
      event_count = sum(means$event_count),
      net_5_5bp = if (nrow(active)) mean(active$net_5_5bp) else NA_real_,
      net_10_5bp = if (nrow(active)) mean(active$net_10_5bp) else NA_real_,
      net_20_5bp = if (nrow(active)) mean(active$net_20_5bp) else NA_real_,
      net_10_10bp = if (nrow(active)) mean(active$net_10_10bp) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_s0_non_event_controls <- function(
  opportunities,
  selected_events,
  contract = g5_s0_contract()
) {
  set.seed(as.integer(contract$non_event_seed))
  keys <- unique(selected_events[, c("fold_id", "pair_id")])
  controls <- list()
  for (key_i in seq_len(nrow(keys))) {
    fold <- keys$fold_id[[key_i]]
    pair <- keys$pair_id[[key_i]]
    events <- selected_events[
      selected_events$fold_id == fold & selected_events$pair_id == pair,
      ,
      drop = FALSE
    ]
    quiet <- opportunities[
      opportunities$fold_id == fold &
        opportunities$pair_id == pair &
        is.finite(opportunities$z) &
        abs(opportunities$z) < contract$quiet_z_threshold,
      ,
      drop = FALSE
    ]
    if (!nrow(quiet)) next
    quiet <- quiet[sample(seq_len(nrow(quiet))), , drop = FALSE]
    keep <- logical(nrow(quiet))
    accepted_signal_indices <- integer()
    for (i in seq_len(nrow(quiet))) {
      if (length(accepted_signal_indices) &&
          any(abs(quiet$signal_session_index[[i]] - accepted_signal_indices) <=
            contract$embargo_sessions)) next
      keep[[i]] <- TRUE
      accepted_signal_indices <- c(
        accepted_signal_indices, quiet$signal_session_index[[i]]
      )
      if (sum(keep) >= nrow(events)) break
    }
    quiet <- quiet[keep, , drop = FALSE]
    n_match <- min(nrow(events), nrow(quiet))
    if (!n_match) next
    quiet <- quiet[seq_len(n_match), , drop = FALSE]
    events <- events[order(events$signal_date), , drop = FALSE][seq_len(n_match), , drop = FALSE]
    quiet <- g5_s0_add_fade_returns(quiet, events$fade_direction, contract)
    quiet$matched_event_signal_date <- events$signal_date
    controls[[length(controls) + 1L]] <- quiet
  }
  out <- do.call(rbind, controls)
  if (is.null(out)) {
    out <- g5_s0_add_fade_returns(opportunities[0, , drop = FALSE], numeric(), contract)
  }
  rownames(out) <- NULL
  out
}

g5_s0_control_quarter_summary <- function(
  controls,
  selected_events,
  contract = g5_s0_contract()
) {
  folds <- sort(unique(selected_events$fold_id))
  rows <- lapply(folds, function(fold) {
    event_fold <- selected_events[selected_events$fold_id == fold, , drop = FALSE]
    control_fold <- controls[controls$fold_id == fold, , drop = FALSE]
    event_pair <- tapply(event_fold$net_10_5bp, event_fold$pair_id, mean)
    control_pair <- tapply(control_fold$net_10_5bp, control_fold$pair_id, mean)
    common <- intersect(names(event_pair), names(control_pair))
    data.frame(
      fold_id = fold,
      evaluation_period = event_fold$evaluation_period[[1L]],
      event_count = nrow(event_fold),
      control_count = nrow(control_fold),
      event_pair_equal = if (length(common)) mean(event_pair[common]) else NA_real_,
      control_pair_equal = if (length(common)) mean(control_pair[common]) else NA_real_,
      event_minus_control = if (length(common)) {
        mean(event_pair[common] - control_pair[common])
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_s0_random_select_group <- function(candidates, target_count, attempts = 100L) {
  if (target_count == 0L) return(character())
  if (nrow(candidates) < target_count) return(NULL)
  for (attempt in seq_len(attempts)) {
    order_i <- sample(seq_len(nrow(candidates)))
    selected <- character()
    used <- character()
    for (i in order_i) {
      if (candidates$symbol_a[[i]] %in% used ||
          candidates$symbol_b[[i]] %in% used) next
      selected <- c(selected, candidates$pair_id[[i]])
      used <- c(used, candidates$symbol_a[[i]], candidates$symbol_b[[i]])
      if (length(selected) >= target_count) return(selected)
    }
  }
  NULL
}

g5_s0_random_control <- function(
  pair_fits,
  pair_means,
  contract = g5_s0_contract()
) {
  confirmation_folds <- sort(unique(pair_fits$fold_id[
    pair_fits$evaluation_period == "confirmation_2022_2024"
  ]))
  selected_counts <- aggregate(
    pair_id ~ fold_id + economic_group,
    pair_fits[pair_fits$selected & pair_fits$fold_id %in% confirmation_folds, , drop = FALSE],
    length
  )
  names(selected_counts)[[3L]] <- "target_count"
  set.seed(as.integer(contract$random_seed))
  policy_values <- rep(NA_real_, contract$random_policy_count)
  detail <- list()
  for (policy_i in seq_len(contract$random_policy_count)) {
    fold_values <- numeric()
    policy_valid <- TRUE
    for (fold in confirmation_folds) {
      selected_pairs <- character()
      fold_counts <- selected_counts[selected_counts$fold_id == fold, , drop = FALSE]
      for (group_i in seq_len(nrow(fold_counts))) {
        group <- fold_counts$economic_group[[group_i]]
        candidates <- pair_fits[
          pair_fits$fold_id == fold &
            pair_fits$economic_group == group &
            pair_fits$structural_eligible,
          ,
          drop = FALSE
        ]
        chosen <- g5_s0_random_select_group(
          candidates, fold_counts$target_count[[group_i]]
        )
        if (is.null(chosen)) {
          policy_valid <- FALSE
          break
        }
        selected_pairs <- c(selected_pairs, chosen)
      }
      if (!policy_valid) break
      means <- pair_means[
        pair_means$fold_id == fold &
          pair_means$pair_id %in% selected_pairs &
          pair_means$event_count > 0,
        ,
        drop = FALSE
      ]
      value <- if (nrow(means)) mean(means$net_10_5bp) else NA_real_
      if (!is.finite(value)) {
        policy_valid <- FALSE
        break
      }
      fold_values <- c(fold_values, value)
      detail[[length(detail) + 1L]] <- data.frame(
        policy_id = policy_i,
        fold_id = fold,
        pair_count = length(selected_pairs),
        active_pair_count = nrow(means),
        net_10_5bp = value,
        stringsAsFactors = FALSE
      )
    }
    if (policy_valid && length(fold_values) == length(confirmation_folds)) {
      policy_values[[policy_i]] <- mean(fold_values)
    }
  }
  distribution <- data.frame(
    schema_version = g5_s0_schema_version(),
    policy_id = seq_len(contract$random_policy_count),
    mean_confirmation_net_10_5bp = policy_values,
    valid = is.finite(policy_values),
    stringsAsFactors = FALSE
  )
  list(
    distribution = distribution,
    detail = if (length(detail)) do.call(rbind, detail) else data.frame(),
    seed = contract$random_seed
  )
}

g5_s0_attribution <- function(
  selected_events,
  quarter_summary,
  contract = g5_s0_contract()
) {
  confirmation_folds <- quarter_summary$fold_id[
    quarter_summary$evaluation_period == "confirmation_2022_2024" &
      is.finite(quarter_summary$net_10_5bp)
  ]
  x <- selected_events[selected_events$fold_id %in% confirmation_folds, , drop = FALSE]
  if (!nrow(x)) return(list(detail = data.frame(), by_group = data.frame(), by_pair = data.frame(), by_year = data.frame()))
  pair_event_counts <- table(interaction(x$fold_id, x$pair_id, drop = TRUE))
  active_pair_counts <- tapply(x$pair_id, x$fold_id, function(v) length(unique(v)))
  fold_count <- length(unique(confirmation_folds))
  x$pair_fold_key <- interaction(x$fold_id, x$pair_id, drop = TRUE)
  x$calendar_year <- as.integer(format(x$signal_date, "%Y"))
  x$contribution <- x$net_10_5bp /
    as.numeric(pair_event_counts[as.character(x$pair_fold_key)]) /
    as.numeric(active_pair_counts[x$fold_id]) /
    fold_count
  summarize <- function(column) {
    values <- tapply(x$contribution, x[[column]], sum)
    positive <- pmax(values, 0)
    total_positive <- sum(positive)
    data.frame(
      key = names(values),
      arithmetic_contribution = as.numeric(values),
      positive_contribution_share = if (total_positive > 0) {
        as.numeric(positive / total_positive)
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  }
  group <- summarize("economic_group")
  names(group)[[1L]] <- "economic_group"
  pair <- summarize("pair_id")
  names(pair)[[1L]] <- "pair_id"
  year <- summarize("calendar_year")
  names(year)[[1L]] <- "calendar_year"
  list(detail = x, by_group = group, by_pair = pair, by_year = year)
}

g5_s0_relationship_stability <- function(
  pair_fits,
  contract = g5_s0_contract()
) {
  selected <- pair_fits[
    pair_fits$selected &
      pair_fits$evaluation_period == "confirmation_2022_2024",
    ,
    drop = FALSE
  ]
  fold_order <- unique(pair_fits$fold_id[order(pair_fits$formation_date)])
  rows <- lapply(seq_len(nrow(selected)), function(i) {
    row <- selected[i, , drop = FALSE]
    fold_i <- match(row$fold_id, fold_order)
    next_fold <- if (fold_i < length(fold_order)) fold_order[[fold_i + 1L]] else NA_character_
    next_row <- pair_fits[
      pair_fits$fold_id == next_fold & pair_fits$pair_id == row$pair_id,
      ,
      drop = FALSE
    ]
    data.frame(
      fold_id = row$fold_id,
      pair_id = row$pair_id,
      economic_group = row$economic_group,
      next_fold_id = next_fold,
      survives = nrow(next_row) == 1L && isTRUE(next_row$structural_eligible[[1L]]),
      stringsAsFactors = FALSE
    )
  })
  detail <- do.call(rbind, rows)
  quarterly <- aggregate(survives ~ fold_id, detail, mean)
  names(quarterly)[[2L]] <- "survival_rate"
  list(detail = detail, quarterly = quarterly, overall = mean(detail$survives))
}

g5_s0_integrity_audit <- function(
  bars,
  pair_fits,
  selected_events,
  contract = g5_s0_contract(),
  data_health_status = "PASS"
) {
  embargo_ok <- TRUE
  if (nrow(selected_events)) {
    pieces <- split(
      selected_events,
      interaction(selected_events$fold_id, selected_events$pair_id, drop = TRUE)
    )
    embargo_ok <- all(vapply(pieces, function(x) {
      x <- x[order(x$signal_session_index), , drop = FALSE]
      if (nrow(x) < 2L) return(TRUE)
      all(x$signal_session_index[-1L] >= x$endpoint_20_session_index[-nrow(x)])
    }, logical(1L)))
  }
  checks <- c(
    data_health = identical(data_health_status, "PASS"),
    explicit_as_of = identical(contract$as_of_timestamp, "2026-07-24 17:30:00"),
    adjusted_daily_authority = !("adjusted" %in% names(bars)) || all(bars$adjusted %in% TRUE),
    no_duplicate_bars = !anyDuplicated(paste(bars$symbol, bars$session_date)),
    no_future_bars = max(bars$session_date) <= as.Date(substr(contract$as_of_timestamp, 1, 10)),
    lexical_pair_orientation = all(pair_fits$symbol_a < pair_fits$symbol_b),
    selected_pairs_train_eligible = all(pair_fits$structural_eligible[pair_fits$selected]),
    next_open_execution = !nrow(selected_events) || all(selected_events$entry_date > selected_events$signal_date),
    endpoint_ordering = !nrow(selected_events) || all(
      selected_events$endpoint_5 > selected_events$entry_date &
        selected_events$endpoint_10 > selected_events$endpoint_5 &
        selected_events$endpoint_20 > selected_events$endpoint_10
    ),
    gross_normalization = !nrow(selected_events) || all(
      abs(abs(selected_events$weight_a) + abs(selected_events$weight_b) - 1) < 1e-10
    ),
    twenty_session_embargo = embargo_ok,
    historical_borrow_not_imputed = !any(c(
      "borrow_status", "shortable", "locate_fee", "borrow_fee"
    ) %in% names(selected_events))
  )
  data.frame(
    check_id = names(checks),
    status = ifelse(checks, "PASS", "FAIL"),
    value = as.character(checks),
    stringsAsFactors = FALSE
  )
}

g5_s0_session_coverage_audit <- function(
  bars,
  contract = g5_s0_contract()
) {
  bars <- g5_s0_validate_bars(bars, contract)
  pieces <- split(bars, bars$symbol)
  do.call(rbind, lapply(g5_s0_required_symbols(contract), function(symbol) {
    x <- pieces[[symbol]]
    data.frame(
      symbol = symbol,
      first_session = min(x$session_date),
      last_session = max(x$session_date),
      session_count = nrow(x),
      status = if (nrow(x) >= contract$minimum_train_bars &&
        max(x$session_date) >= contract$oos_end) "PASS" else "FAIL",
      stringsAsFactors = FALSE
    )
  }))
}

g5_s0_gates <- function(
  quarter_summary,
  selected_events,
  random_control,
  control_summary,
  attribution,
  stability,
  integrity,
  contract = g5_s0_contract()
) {
  q <- quarter_summary[
    quarter_summary$evaluation_period == "confirmation_2022_2024",
    ,
    drop = FALSE
  ]
  controls <- control_summary[
    control_summary$evaluation_period == "confirmation_2022_2024",
    ,
    drop = FALSE
  ]
  mean_primary <- mean(q$net_10_5bp, na.rm = TRUE)
  positive_primary <- sum(q$net_10_5bp > 0, na.rm = TRUE)
  pair_breadth <- sum(
    q$selected_pair_count >= contract$minimum_pairs &
      q$selected_group_count >= contract$minimum_groups
  )
  event_counts <- table(selected_events$pair_id[
    selected_events$evaluation_period == "confirmation_2022_2024"
  ])
  total_events <- sum(q$event_count)
  valid_random <- random_control$distribution$mean_confirmation_net_10_5bp[
    random_control$distribution$valid
  ]
  random_p90 <- if (length(valid_random)) {
    as.numeric(stats::quantile(valid_random, contract$random_percentile, names = FALSE))
  } else {
    NA_real_
  }
  match_rate <- if (sum(controls$event_count) > 0) {
    sum(controls$control_count) / sum(controls$event_count)
  } else {
    0
  }
  control_difference <- mean(controls$event_minus_control, na.rm = TRUE)
  positive_control_quarters <- sum(controls$event_minus_control > 0, na.rm = TRUE)
  stress_mean <- mean(q$net_10_10bp, na.rm = TRUE)
  h5_mean <- mean(q$net_5_5bp, na.rm = TRUE)
  h20_mean <- mean(q$net_20_5bp, na.rm = TRUE)
  max_share <- function(x) {
    if (!nrow(x) || all(!is.finite(x$positive_contribution_share))) Inf
    else max(x$positive_contribution_share, na.rm = TRUE)
  }
  concentration_pass <-
    max_share(attribution$by_group) <= contract$group_contribution_cap &&
    max_share(attribution$by_pair) <= contract$pair_contribution_cap &&
    max_share(attribution$by_year) <= contract$year_contribution_cap
  stability_pass <- is.finite(stability$overall) &&
    stability$overall >= contract$minimum_relationship_survival &&
    nrow(stability$quarterly) == nrow(q) &&
    all(stability$quarterly$survival_rate >= contract$minimum_quarter_survival)
  pass <- c(
    all(integrity$status == "PASS"),
    pair_breadth >= contract$pair_breadth_quarters,
    total_events >= contract$minimum_events &&
      all(q$event_count > 0) &&
      sum(event_counts >= 5L) >= contract$minimum_pairs_with_five_events,
    is.finite(mean_primary) && mean_primary > 0 &&
      positive_primary >= contract$positive_quarters,
    is.finite(random_p90) && mean_primary > random_p90,
    is.finite(control_difference) && control_difference > 0 &&
      positive_control_quarters >= contract$positive_quarters &&
      match_rate >= contract$minimum_control_match,
    is.finite(stress_mean) && stress_mean >= 0 &&
      !(h5_mean <= 0 && h20_mean <= 0),
    concentration_pass,
    stability_pass
  )
  data.frame(
    gate_id = paste0("S0A_G", seq_len(9L)),
    gate = c(
      "Integrity and leakage checks",
      "Pair and group breadth",
      "Independent event support",
      "Positive primary convergence",
      "Selected pairs beat random p90",
      "Events beat same-pair non-events",
      "Cost and horizon robustness",
      "Pair, group, and year contribution breadth",
      "Next-formation relationship stability"
    ),
    status = ifelse(pass, "PASS", "FAIL"),
    value = c(
      sprintf("%d/%d checks pass", sum(integrity$status == "PASS"), nrow(integrity)),
      sprintf("%d/12 quarters meet breadth", pair_breadth),
      sprintf("%d events; %d pairs with >=5", total_events, sum(event_counts >= 5L)),
      sprintf("%.2f bp; %d/12 positive", 10000 * mean_primary, positive_primary),
      sprintf("observed %.2f bp vs p90 %.2f bp", 10000 * mean_primary, 10000 * random_p90),
      sprintf("difference %.2f bp; %d/12; %.1f%% matched", 10000 * control_difference, positive_control_quarters, 100 * match_rate),
      sprintf("10bp %.2f; h5 %.2f; h20 %.2f bp", 10000 * stress_mean, 10000 * h5_mean, 10000 * h20_mean),
      sprintf("max group %.1f%%; pair %.1f%%; year %.1f%%", 100 * max_share(attribution$by_group), 100 * max_share(attribution$by_pair), 100 * max_share(attribution$by_year)),
      sprintf("overall %.1f%%; minimum quarter %.1f%%", 100 * stability$overall, 100 * min(stability$quarterly$survival_rate))
    ),
    stringsAsFactors = FALSE
  )
}

g5_s0_run_analysis <- function(
  bars,
  contract = g5_s0_contract(),
  data_health_status = "PASS"
) {
  contract <- g5_s0_validate_contract(contract)
  bars <- g5_s0_validate_bars(bars, contract)
  schedule <- g5_s0_schedule(bars, contract)
  eligibility <- g5_s0_symbol_eligibility(bars, schedule, contract)
  pair_fits <- g5_s0_build_pair_fits(bars, schedule, eligibility, contract)
  opportunities <- g5_s0_opportunity_table(bars, pair_fits, contract)
  events <- g5_s0_event_table(opportunities, contract)
  selected_events <- events[events$selected_pair, , drop = FALSE]
  pair_means <- g5_s0_pair_means(events, pair_fits, contract)
  quarter_summary <- g5_s0_quarter_summary(pair_means, pair_fits, TRUE, contract)
  controls <- g5_s0_non_event_controls(opportunities, selected_events, contract)
  control_summary <- g5_s0_control_quarter_summary(controls, selected_events, contract)
  random_control <- g5_s0_random_control(pair_fits, pair_means, contract)
  attribution <- g5_s0_attribution(selected_events, quarter_summary, contract)
  stability <- g5_s0_relationship_stability(pair_fits, contract)
  integrity <- g5_s0_integrity_audit(
    bars, pair_fits, selected_events, contract, data_health_status
  )
  gates <- g5_s0_gates(
    quarter_summary, selected_events, random_control, control_summary,
    attribution, stability, integrity, contract
  )
  list(
    contract = contract,
    schedule = schedule,
    symbol_eligibility = eligibility,
    pair_fits = pair_fits,
    opportunities = opportunities,
    events = events,
    selected_events = selected_events,
    pair_means = pair_means,
    quarter_summary = quarter_summary,
    non_event_controls = controls,
    control_summary = control_summary,
    random_control = random_control,
    attribution = attribution,
    stability = stability,
    integrity = integrity,
    session_coverage = g5_s0_session_coverage_audit(bars, contract),
    gates = gates,
    overall_status = if (all(gates$status == "PASS")) {
      "PASS_S0A_TO_PROSPECTIVE_BORROW_SHADOW_DISCUSSION"
    } else {
      "STOP_S0A_RELATIVE_VALUE_MECHANISM"
    }
  )
}
