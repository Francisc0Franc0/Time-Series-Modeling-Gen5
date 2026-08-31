edl_ms01_attention_falsification_contract <- function() {
  list(
    study_id = "EDL_MS_01_ATTENTION_FALSIFICATION_01",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    target_category = "TRIGGERED_PROXY__STRONG_RECLAIM",
    attention_cohort = "ATTENTION_SUPPLEMENT",
    core_cohort = "GICS_CORE",
    exact_match = "calendar_year",
    expected_common_years = c("2018", "2020", "2022", "2023"),
    expected_pair_count = 20L,
    distance_features = c(
      "minimum_intraday_return",
      "close_location_value",
      "log_abnormal_dollar_volume",
      "session_date_numeric"
    ),
    primary_horizon = 5L,
    context_horizons = 0:10,
    alpha = 0.05,
    max_abs_smd = 0.25,
    require_all_leave_one_year_out_positive = TRUE,
    require_all_leave_one_attention_symbol_out_positive = TRUE
  )
}

edl_ms01_validate_attention_falsification_contract <- function(
  contract = edl_ms01_attention_falsification_contract()
) {
  if (!identical(contract$analysis_start, as.Date("2018-01-02")) ||
      !identical(contract$analysis_end, as.Date("2023-12-29"))) {
    edl_ms01_stop("The attention falsification TRAIN window changed.")
  }
  if (!identical(contract$target_category, "TRIGGERED_PROXY__STRONG_RECLAIM") ||
      !identical(contract$primary_horizon, 5L) ||
      !identical(contract$context_horizons, 0:10)) {
    edl_ms01_stop("The attention falsification target or horizon changed.")
  }
  expected_features <- c(
    "minimum_intraday_return",
    "close_location_value",
    "log_abnormal_dollar_volume",
    "session_date_numeric"
  )
  if (!identical(contract$distance_features, expected_features) ||
      !identical(contract$exact_match, "calendar_year")) {
    edl_ms01_stop("The outcome-blind matching specification changed.")
  }
  if (!identical(contract$expected_common_years, c("2018", "2020", "2022", "2023")) ||
      !identical(contract$expected_pair_count, 20L)) {
    edl_ms01_stop("The pre-outcome common-year pair-count contract changed.")
  }
  if (!identical(contract$alpha, 0.05) ||
      !identical(contract$max_abs_smd, 0.25)) {
    edl_ms01_stop("The falsification decision thresholds changed.")
  }
  contract
}

edl_ms01_attention_match_pool <- function(
  events,
  contract = edl_ms01_attention_falsification_contract()
) {
  contract <- edl_ms01_validate_attention_falsification_contract(contract)
  required <- c(
    "symbol", "session_date", "atlas_cohort", "instrument_type",
    "event_category", "minimum_intraday_return", "close_location_value",
    "abnormal_dollar_volume"
  )
  missing <- setdiff(required, names(events))
  if (length(missing)) {
    edl_ms01_stop(paste("Missing match-pool columns:", paste(missing, collapse = ", ")))
  }
  out <- events[
    events$instrument_type == "Stock" &
      events$event_category == contract$target_category &
      events$atlas_cohort %in% c(contract$attention_cohort, contract$core_cohort),
    , drop = FALSE
  ]
  out$session_date <- as.Date(out$session_date)
  out <- out[
    out$session_date >= contract$analysis_start &
      out$session_date <= contract$analysis_end,
    , drop = FALSE
  ]
  out$calendar_year <- format(out$session_date, "%Y")
  out$session_date_numeric <- as.numeric(out$session_date)
  out$log_abnormal_dollar_volume <- log(out$abnormal_dollar_volume)
  finite_features <- vapply(
    out[contract$distance_features],
    function(x) is.finite(as.numeric(x)),
    logical(nrow(out))
  )
  if (is.null(dim(finite_features))) {
    finite_rows <- finite_features
  } else {
    finite_rows <- apply(finite_features, 1L, all)
  }
  out$match_feature_eligible <- finite_rows
  out$event_id <- paste(out$symbol, out$session_date, sep = "__")
  out <- out[order(out$calendar_year, out$atlas_cohort, out$session_date, out$symbol), ]
  rownames(out) <- NULL
  out
}

edl_ms01_robust_scale <- function(x) {
  x <- as.numeric(x)
  value <- stats::mad(x, center = stats::median(x), constant = 1.4826)
  if (!is.finite(value) || value <= 0) value <- stats::sd(x)
  if (!is.finite(value) || value <= 0) value <- 1
  value
}

edl_ms01_standardize_attention_pool <- function(
  pool,
  contract = edl_ms01_attention_falsification_contract()
) {
  contract <- edl_ms01_validate_attention_falsification_contract(contract)
  pool <- pool[pool$match_feature_eligible, , drop = FALSE]
  common_years <- intersect(
    unique(pool$calendar_year[pool$atlas_cohort == contract$attention_cohort]),
    unique(pool$calendar_year[pool$atlas_cohort == contract$core_cohort])
  )
  pool <- pool[pool$calendar_year %in% common_years, , drop = FALSE]
  if (!nrow(pool)) edl_ms01_stop("No common-year attention/core matching pool remains.")
  rows <- lapply(sort(common_years), function(year) {
    x <- pool[pool$calendar_year == year, , drop = FALSE]
    for (feature in contract$distance_features) {
      center <- stats::median(as.numeric(x[[feature]]))
      scale <- edl_ms01_robust_scale(x[[feature]])
      x[[paste0("z__", feature)]] <- (as.numeric(x[[feature]]) - center) / scale
    }
    x
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$calendar_year, out$atlas_cohort, out$session_date, out$symbol), ]
}

edl_ms01_match_attention_to_core <- function(
  events,
  contract = edl_ms01_attention_falsification_contract()
) {
  contract <- edl_ms01_validate_attention_falsification_contract(contract)
  raw_pool <- edl_ms01_attention_match_pool(events, contract)
  pool <- edl_ms01_standardize_attention_pool(raw_pool, contract)
  z_features <- paste0("z__", contract$distance_features)
  years <- sort(unique(pool$calendar_year))
  pair_rows <- list()
  pair_index <- 0L
  for (year in years) {
    attention <- pool[
      pool$calendar_year == year & pool$atlas_cohort == contract$attention_cohort,
      , drop = FALSE
    ]
    core <- pool[
      pool$calendar_year == year & pool$atlas_cohort == contract$core_cohort,
      , drop = FALSE
    ]
    candidates <- expand.grid(
      attention_index = seq_len(nrow(attention)),
      core_index = seq_len(nrow(core)),
      KEEP.OUT.ATTRS = FALSE,
      stringsAsFactors = FALSE
    )
    candidates$distance <- vapply(seq_len(nrow(candidates)), function(i) {
      a <- attention[candidates$attention_index[[i]], z_features, drop = FALSE]
      c <- core[candidates$core_index[[i]], z_features, drop = FALSE]
      sqrt(sum((as.numeric(a[1, ]) - as.numeric(c[1, ]))^2))
    }, numeric(1))
    candidates$attention_date <- attention$session_date[candidates$attention_index]
    candidates$attention_symbol <- attention$symbol[candidates$attention_index]
    candidates$core_date <- core$session_date[candidates$core_index]
    candidates$core_symbol <- core$symbol[candidates$core_index]
    candidates <- candidates[order(
      candidates$distance,
      candidates$attention_date,
      candidates$attention_symbol,
      candidates$core_date,
      candidates$core_symbol
    ), ]
    used_attention <- logical(nrow(attention))
    used_core <- logical(nrow(core))
    target_n <- min(nrow(attention), nrow(core))
    for (i in seq_len(nrow(candidates))) {
      ai <- candidates$attention_index[[i]]
      ci <- candidates$core_index[[i]]
      if (used_attention[[ai]] || used_core[[ci]]) next
      used_attention[[ai]] <- TRUE
      used_core[[ci]] <- TRUE
      pair_index <- pair_index + 1L
      row <- data.frame(
        pair_id = sprintf("PAIR_%03d", pair_index),
        calendar_year = year,
        distance = candidates$distance[[i]],
        attention_event_id = attention$event_id[[ai]],
        attention_symbol = attention$symbol[[ai]],
        attention_session_date = attention$session_date[[ai]],
        core_event_id = core$event_id[[ci]],
        core_symbol = core$symbol[[ci]],
        core_session_date = core$session_date[[ci]],
        stringsAsFactors = FALSE
      )
      for (feature in contract$distance_features) {
        row[[paste0("attention__", feature)]] <- attention[[feature]][[ai]]
        row[[paste0("core__", feature)]] <- core[[feature]][[ci]]
        row[[paste0("attention_z__", feature)]] <- attention[[paste0("z__", feature)]][[ai]]
        row[[paste0("core_z__", feature)]] <- core[[paste0("z__", feature)]][[ci]]
      }
      pair_rows[[length(pair_rows) + 1L]] <- row
      if (sum(used_attention) == target_n || sum(used_core) == target_n) break
    }
  }
  pairs <- do.call(rbind, pair_rows)
  pairs <- pairs[order(pairs$calendar_year, pairs$attention_session_date, pairs$attention_symbol), ]
  pairs$pair_id <- sprintf("PAIR_%03d", seq_len(nrow(pairs)))
  rownames(pairs) <- NULL
  list(raw_pool = raw_pool, standardized_pool = pool, pairs = pairs)
}

edl_ms01_attention_balance <- function(
  standardized_pool,
  pairs,
  contract = edl_ms01_attention_falsification_contract()
) {
  contract <- edl_ms01_validate_attention_falsification_contract(contract)
  rows <- lapply(contract$distance_features, function(feature) {
    z_feature <- paste0("z__", feature)
    attention_before <- standardized_pool[[z_feature]][
      standardized_pool$atlas_cohort == contract$attention_cohort
    ]
    core_before <- standardized_pool[[z_feature]][
      standardized_pool$atlas_cohort == contract$core_cohort
    ]
    attention_after <- pairs[[paste0("attention_z__", feature)]]
    core_after <- pairs[[paste0("core_z__", feature)]]
    smd <- function(a, b) {
      denom <- sqrt((stats::var(a) + stats::var(b)) / 2)
      if (!is.finite(denom) || denom <= 0) return(0)
      (mean(a) - mean(b)) / denom
    }
    data.frame(
      feature = feature,
      attention_n_before = length(attention_before),
      core_n_before = length(core_before),
      attention_n_after = length(attention_after),
      core_n_after = length(core_after),
      smd_before = smd(attention_before, core_before),
      smd_after = smd(attention_after, core_after),
      abs_smd_after = abs(smd(attention_after, core_after)),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

edl_ms01_exact_sign_flip_p <- function(differences, alternative = "greater") {
  differences <- as.numeric(differences)
  differences <- differences[is.finite(differences)]
  n <- length(differences)
  if (!n) edl_ms01_stop("No finite paired differences for sign-flip inference.")
  if (n > 24L) edl_ms01_stop("Exact sign-flip enumeration is capped at 24 pairs.")
  null_sums <- 0
  for (value in differences) null_sums <- c(null_sums + value, null_sums - value)
  observed <- mean(differences)
  null_means <- null_sums / n
  p_value <- switch(
    alternative,
    greater = mean(null_means >= observed - 1e-15),
    less = mean(null_means <= observed + 1e-15),
    two.sided = mean(abs(null_means) >= abs(observed) - 1e-15),
    edl_ms01_stop("Unknown sign-flip alternative.")
  )
  data.frame(
    pair_n = n,
    observed_mean_difference = observed,
    alternative = alternative,
    exact_assignments = length(null_means),
    exact_p_value = p_value,
    stringsAsFactors = FALSE
  )
}

edl_ms01_classify_attention_falsification <- function(
  balance_pass,
  observed_mean_difference,
  exact_p_value,
  all_leave_one_year_out_positive,
  all_leave_one_attention_symbol_out_positive,
  contract = edl_ms01_attention_falsification_contract()
) {
  contract <- edl_ms01_validate_attention_falsification_contract(contract)
  if (!isTRUE(balance_pass)) return("INCONCLUSIVE_MATCH_BALANCE_FAILED")
  primary_pass <- is.finite(observed_mean_difference) &&
    observed_mean_difference > 0 && is.finite(exact_p_value) &&
    exact_p_value <= contract$alpha
  robustness_pass <- isTRUE(all_leave_one_year_out_positive) &&
    isTRUE(all_leave_one_attention_symbol_out_positive)
  if (primary_pass && robustness_pass) {
    "ATTENTION_DISTINCTION_SURVIVES_NARROW_FALSIFICATION"
  } else {
    "ATTENTION_DISTINCTION_DOES_NOT_SURVIVE_NARROW_FALSIFICATION"
  }
}
