# Gen5.4 N1C news nonredundancy helpers.
#
# This module tests whether the frozen N1B news-intensity measurement retains
# future-volatility ordering after conditioning on two predeclared OHLCV
# controls. It does not fit a predictive model or compute policy, allocation,
# portfolio, PnL, sentiment, or live-advice outputs.

g5_gen54_n1c_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message) else stop(message, call. = FALSE)
}

g5_gen54_n1c_unify_bars <- function(
    bars,
    issuer_registry = g5_gen54_n1b_issuer_registry()) {
  required <- c("symbol", "session_date", "open", "close", "volume")
  missing <- setdiff(required, names(bars))
  if (length(missing)) {
    g5_gen54_n1c_stop(paste("bars missing:", paste(missing, collapse = ", ")))
  }
  x <- bars
  x$symbol <- toupper(trimws(as.character(x$symbol)))
  x$session_date <- as.Date(x$session_date)
  registry_row <- match(x$symbol, issuer_registry$provider_symbol)
  keep <- !is.na(registry_row)
  x <- x[keep, , drop = FALSE]
  registry_row <- registry_row[keep]
  x$issuer_id <- issuer_registry$issuer_id[registry_row]
  x$provider_symbol <- x$symbol
  x$symbol_valid_on_session <- x$session_date >= issuer_registry$valid_from[registry_row] &
    x$session_date <= issuer_registry$valid_to[registry_row]
  x <- x[
    x$symbol_valid_on_session,
    c("issuer_id", "provider_symbol", "session_date", "open", "close", "volume"),
    drop = FALSE
  ]
  x <- x[order(x$issuer_id, x$session_date, x$provider_symbol), , drop = FALSE]
  if (anyDuplicated(x[, c("issuer_id", "session_date")])) {
    g5_gen54_n1c_stop("Point-in-time issuer bars contain duplicate issuer/session rows.")
  }
  rownames(x) <- NULL
  x
}

g5_gen54_n1c_control_series <- function(
    issuer_bars,
    session_dates,
    prior_horizon = 5L,
    dollar_volume_lookback = 60L) {
  prior_horizon <- as.integer(prior_horizon)
  dollar_volume_lookback <- as.integer(dollar_volume_lookback)
  if (!identical(prior_horizon, 5L)) {
    g5_gen54_n1c_stop("N1C freezes prior path volatility at five sessions.")
  }
  if (!identical(dollar_volume_lookback, 60L)) {
    g5_gen54_n1c_stop("N1C freezes the dollar-volume baseline at 60 prior sessions.")
  }
  required <- c("issuer_id", "session_date", "open", "close", "volume")
  missing <- setdiff(required, names(issuer_bars))
  if (length(missing)) {
    g5_gen54_n1c_stop(paste("issuer_bars missing:", paste(missing, collapse = ", ")))
  }
  sessions <- sort(unique(as.Date(session_dates)))
  if (!length(sessions)) g5_gen54_n1c_stop("N1C requires a non-empty market calendar.")

  parts <- lapply(sort(unique(issuer_bars$issuer_id)), function(issuer) {
    bars <- issuer_bars[issuer_bars$issuer_id == issuer, required[-1L], drop = FALSE]
    aligned <- merge(
      data.frame(session_date = sessions),
      bars,
      by = "session_date",
      all.x = TRUE,
      sort = TRUE
    )
    n <- nrow(aligned)
    prior_path <- rep(NA_real_, n)
    dollar_volume <- aligned$close * aligned$volume
    dollar_volume_surprise <- rep(NA_real_, n)
    prior_path_start <- as.Date(rep(NA_real_, n), origin = "1970-01-01")
    prior_path_end <- as.Date(rep(NA_real_, n), origin = "1970-01-01")
    dollar_baseline_start <- as.Date(rep(NA_real_, n), origin = "1970-01-01")
    dollar_baseline_end <- as.Date(rep(NA_real_, n), origin = "1970-01-01")

    if (n >= prior_horizon) {
      for (i in seq.int(prior_horizon, n)) {
        index <- seq.int(i - prior_horizon + 1L, i)
        opens <- aligned$open[index]
        closes <- aligned$close[index]
        if (all(is.finite(opens)) && all(is.finite(closes)) &&
            opens[[1L]] > 0 && all(closes > 0)) {
          returns <- c(log(closes[[1L]] / opens[[1L]]), diff(log(closes)))
          prior_path[[i]] <- sqrt(sum(returns^2))
          prior_path_start[[i]] <- aligned$session_date[index[[1L]]]
          prior_path_end[[i]] <- aligned$session_date[[i]]
        }
      }
    }

    first_dollar_index <- dollar_volume_lookback + 1L
    if (n >= first_dollar_index) {
      for (i in seq.int(first_dollar_index, n)) {
        baseline_index <- seq.int(i - dollar_volume_lookback, i - 1L)
        baseline <- dollar_volume[baseline_index]
        current <- dollar_volume[[i]]
        if (is.finite(current) && current > 0 &&
            all(is.finite(baseline)) && all(baseline > 0)) {
          baseline_median <- stats::median(baseline)
          if (is.finite(baseline_median) && baseline_median > 0) {
            dollar_volume_surprise[[i]] <- log(current / baseline_median)
            dollar_baseline_start[[i]] <- aligned$session_date[baseline_index[[1L]]]
            dollar_baseline_end[[i]] <- aligned$session_date[baseline_index[[length(baseline_index)]]]
          }
        }
      }
    }

    data.frame(
      issuer_id = issuer,
      decision_session = aligned$session_date,
      prior_path_volatility_h5 = prior_path,
      prior_path_start_session = prior_path_start,
      prior_path_end_session = prior_path_end,
      current_dollar_volume = dollar_volume,
      dollar_volume_surprise_1_60 = dollar_volume_surprise,
      dollar_volume_baseline_start_session = dollar_baseline_start,
      dollar_volume_baseline_end_session = dollar_baseline_end,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  out
}

g5_gen54_n1c_attach_controls <- function(
    n1b_oos,
    control_series,
    minimum_train_control_rows = 400L) {
  required_oos <- c(
    "fold_id", "issuer_id", "decision_session", "train_start_date",
    "train_end_date", "news_intensity_percentile",
    "relative_future_path_volatility_h5"
  )
  missing_oos <- setdiff(required_oos, names(n1b_oos))
  if (length(missing_oos)) {
    g5_gen54_n1c_stop(paste("n1b_oos missing:", paste(missing_oos, collapse = ", ")))
  }
  required_controls <- c(
    "issuer_id", "decision_session", "prior_path_volatility_h5",
    "prior_path_start_session", "prior_path_end_session",
    "current_dollar_volume", "dollar_volume_surprise_1_60",
    "dollar_volume_baseline_start_session",
    "dollar_volume_baseline_end_session"
  )
  missing_controls <- setdiff(required_controls, names(control_series))
  if (length(missing_controls)) {
    g5_gen54_n1c_stop(paste("control_series missing:", paste(missing_controls, collapse = ", ")))
  }
  if (anyDuplicated(n1b_oos[, c("fold_id", "issuer_id", "decision_session")])) {
    g5_gen54_n1c_stop("N1B OOS authority contains duplicate fold/issuer/session rows.")
  }
  if (anyDuplicated(control_series[, c("issuer_id", "decision_session")])) {
    g5_gen54_n1c_stop("N1C control series contains duplicate issuer/session rows.")
  }

  out <- n1b_oos
  control_key <- paste(control_series$issuer_id, control_series$decision_session, sep = "\r")
  out_key <- paste(out$issuer_id, out$decision_session, sep = "\r")
  control_row <- match(out_key, control_key)
  for (column in setdiff(required_controls, c("issuer_id", "decision_session"))) {
    out[[column]] <- control_series[[column]][control_row]
  }
  out$relative_prior_path_volatility_h5 <- NA_real_
  out$train_prior_path_volatility_median_h5 <- NA_real_
  out$control_scale_max_session <- as.Date(NA)

  support_rows <- list()
  support_index <- 1L
  fold_issuer <- unique(out[, c(
    "fold_id", "issuer_id", "train_start_date", "train_end_date"
  )])
  fold_issuer <- fold_issuer[order(fold_issuer$fold_id, fold_issuer$issuer_id), , drop = FALSE]
  for (i in seq_len(nrow(fold_issuer))) {
    item <- fold_issuer[i, , drop = FALSE]
    train <- control_series[
      control_series$issuer_id == item$issuer_id &
        control_series$decision_session >= item$train_start_date &
        control_series$decision_session <= item$train_end_date &
        is.finite(control_series$prior_path_volatility_h5),
      ,
      drop = FALSE
    ]
    scale <- if (nrow(train)) stats::median(train$prior_path_volatility_h5) else NA_real_
    support_ok <- nrow(train) >= as.integer(minimum_train_control_rows) &&
      is.finite(scale) && scale > 0
    rows <- out$fold_id == item$fold_id & out$issuer_id == item$issuer_id
    if (support_ok) {
      out$relative_prior_path_volatility_h5[rows] <-
        out$prior_path_volatility_h5[rows] / scale
    }
    out$train_prior_path_volatility_median_h5[rows] <- scale
    out$control_scale_max_session[rows] <-
      if (nrow(train)) max(train$decision_session) else as.Date(NA)
    support_rows[[support_index]] <- data.frame(
      fold_id = item$fold_id,
      issuer_id = item$issuer_id,
      train_start_date = item$train_start_date,
      train_end_date = item$train_end_date,
      train_prior_control_rows = nrow(train),
      train_prior_path_volatility_median_h5 = scale,
      minimum_train_control_rows = as.integer(minimum_train_control_rows),
      support_ok = support_ok,
      stringsAsFactors = FALSE
    )
    support_index <- support_index + 1L
  }
  support <- do.call(rbind, support_rows)
  rownames(out) <- rownames(support) <- NULL
  list(oos = out, train_support = support)
}

g5_gen54_n1c_partial_spearman <- function(
    x,
    y,
    controls,
    minimum = 20L,
    return_details = FALSE) {
  controls <- as.matrix(controls)
  if (!ncol(controls)) g5_gen54_n1c_stop("N1C requires at least one control.")
  keep <- is.finite(x) & is.finite(y) & apply(controls, 1L, function(row) all(is.finite(row)))
  empty <- list(
    correlation = NA_real_,
    keep = keep,
    x_rank = rep(NA_real_, length(x)),
    y_rank = rep(NA_real_, length(y)),
    control_ranks = matrix(NA_real_, nrow = length(x), ncol = ncol(controls)),
    x_residual = rep(NA_real_, length(x)),
    y_residual = rep(NA_real_, length(y))
  )
  colnames(empty$control_ranks) <- colnames(controls)
  if (sum(keep) < as.integer(minimum)) {
    return(if (return_details) empty else empty$correlation)
  }
  x_rank <- rank(x[keep], ties.method = "average")
  y_rank <- rank(y[keep], ties.method = "average")
  control_ranks <- apply(controls[keep, , drop = FALSE], 2L, rank, ties.method = "average")
  if (is.null(dim(control_ranks))) control_ranks <- matrix(control_ranks, ncol = 1L)
  design <- cbind(intercept = 1, control_ranks)
  if (qr(design)$rank < ncol(design)) {
    return(if (return_details) empty else empty$correlation)
  }
  x_residual <- stats::lm.fit(design, x_rank)$residuals
  y_residual <- stats::lm.fit(design, y_rank)$residuals
  correlation <- suppressWarnings(stats::cor(x_residual, y_residual))
  if (!return_details) return(correlation)
  empty$correlation <- correlation
  empty$x_rank[keep] <- x_rank
  empty$y_rank[keep] <- y_rank
  empty$control_ranks[keep, ] <- control_ranks
  empty$x_residual[keep] <- x_residual
  empty$y_residual[keep] <- y_residual
  empty
}

g5_gen54_n1c_evaluate <- function(oos, minimum_fold_rows = 20L) {
  required <- c(
    "fold_id", "issuer_id", "decision_session", "news_intensity_percentile",
    "relative_future_path_volatility_h5",
    "relative_prior_path_volatility_h5", "dollar_volume_surprise_1_60"
  )
  missing <- setdiff(required, names(oos))
  if (length(missing)) {
    g5_gen54_n1c_stop(paste("oos missing:", paste(missing, collapse = ", ")))
  }
  out <- oos
  out$news_rank <- NA_real_
  out$future_volatility_rank <- NA_real_
  out$prior_volatility_rank <- NA_real_
  out$dollar_volume_surprise_rank <- NA_real_
  out$news_rank_residual <- NA_real_
  out$future_volatility_rank_residual <- NA_real_

  rows <- lapply(sort(unique(out$fold_id)), function(fold_id) {
    index <- which(out$fold_id == fold_id)
    part <- out[index, , drop = FALSE]
    controls <- cbind(
      prior_volatility = part$relative_prior_path_volatility_h5,
      dollar_volume_surprise = part$dollar_volume_surprise_1_60
    )
    detail <- g5_gen54_n1c_partial_spearman(
      part$news_intensity_percentile,
      part$relative_future_path_volatility_h5,
      controls,
      minimum = minimum_fold_rows,
      return_details = TRUE
    )
    out$news_rank[index] <<- detail$x_rank
    out$future_volatility_rank[index] <<- detail$y_rank
    out$prior_volatility_rank[index] <<- detail$control_ranks[, 1L]
    out$dollar_volume_surprise_rank[index] <<- detail$control_ranks[, 2L]
    out$news_rank_residual[index] <<- detail$x_residual
    out$future_volatility_rank_residual[index] <<- detail$y_residual
    complete <- detail$keep
    raw_correlation <- if (sum(complete) >= minimum_fold_rows) {
      suppressWarnings(stats::cor(
        part$news_intensity_percentile[complete],
        part$relative_future_path_volatility_h5[complete],
        method = "spearman"
      ))
    } else NA_real_
    cor_safe <- function(a, b) {
      keep <- is.finite(a) & is.finite(b)
      if (sum(keep) < minimum_fold_rows) return(NA_real_)
      suppressWarnings(stats::cor(a[keep], b[keep], method = "spearman"))
    }
    data.frame(
      fold_id = fold_id,
      authority_rows = nrow(part),
      complete_control_rows = sum(complete),
      issuer_count = length(unique(part$issuer_id[complete])),
      raw_spearman_correlation = raw_correlation,
      partial_spearman_correlation = detail$correlation,
      correlation_absorbed_by_controls = raw_correlation - detail$correlation,
      news_vs_prior_volatility_spearman = cor_safe(
        part$news_intensity_percentile,
        part$relative_prior_path_volatility_h5
      ),
      news_vs_dollar_volume_surprise_spearman = cor_safe(
        part$news_intensity_percentile,
        part$dollar_volume_surprise_1_60
      ),
      future_vs_prior_volatility_spearman = cor_safe(
        part$relative_future_path_volatility_h5,
        part$relative_prior_path_volatility_h5
      ),
      future_vs_dollar_volume_surprise_spearman = cor_safe(
        part$relative_future_path_volatility_h5,
        part$dollar_volume_surprise_1_60
      ),
      stringsAsFactors = FALSE
    )
  })
  fold_summary <- do.call(rbind, rows)
  rownames(out) <- rownames(fold_summary) <- NULL
  list(oos = out, fold_summary = fold_summary)
}

g5_gen54_n1c_verdict <- function(
    fold_summary,
    integrity_passed,
    required_positive_folds = 8L) {
  mean_partial <- mean(fold_summary$partial_spearman_correlation, na.rm = TRUE)
  positive_partial <- sum(fold_summary$partial_spearman_correlation > 0, na.rm = TRUE)
  gates <- data.frame(
    gate_id = c(
      "positive_mean_fold_partial_spearman",
      "positive_partial_spearman_in_8_of_12_folds",
      "data_timing_population_train_and_leakage_checks"
    ),
    passed = c(
      is.finite(mean_partial) && mean_partial > 0,
      positive_partial >= as.integer(required_positive_folds),
      isTRUE(integrity_passed)
    ),
    value = c(
      sprintf("%.6f", mean_partial),
      as.character(positive_partial),
      if (isTRUE(integrity_passed)) "PASS" else "FAIL"
    ),
    threshold = c("> 0", paste0(">= ", required_positive_folds), "PASS"),
    stringsAsFactors = FALSE
  )
  list(
    mean_fold_partial_spearman = mean_partial,
    positive_partial_spearman_folds = positive_partial,
    gates = gates,
    passed = all(gates$passed)
  )
}

g5_gen54_n1c_leakage_audit <- function(
    n1b_oos,
    result,
    n1b_fold_summary,
    train_support,
    n1b_status,
    forbidden_analysis_count = 0L,
    tolerance = 1e-12) {
  oos <- result$oos
  fold_summary <- result$fold_summary
  authority_key <- paste(
    n1b_oos$fold_id, n1b_oos$issuer_id, n1b_oos$decision_session, sep = "\r"
  )
  result_key <- paste(oos$fold_id, oos$issuer_id, oos$decision_session, sep = "\r")
  fold_match <- match(fold_summary$fold_id, n1b_fold_summary$fold_id)
  raw_difference <- abs(
    fold_summary$raw_spearman_correlation -
      n1b_fold_summary$spearman_correlation[fold_match]
  )
  population_identical <- identical(authority_key, result_key)
  measurement_identical <- population_identical &&
    isTRUE(all.equal(
      n1b_oos$news_intensity_percentile,
      oos$news_intensity_percentile,
      tolerance = 0,
      check.attributes = FALSE
    )) &&
    isTRUE(all.equal(
      n1b_oos$relative_future_path_volatility_h5,
      oos$relative_future_path_volatility_h5,
      tolerance = 0,
      check.attributes = FALSE
    ))
  controls_complete <- all(
    is.finite(oos$relative_prior_path_volatility_h5) &
      is.finite(oos$dollar_volume_surprise_1_60)
  )
  data.frame(
    check_id = c(
      "accepted_n1b_authority_status",
      "twelve_quarterly_oos_folds",
      "n1b_population_reproduced",
      "n1b_measurement_and_outcome_unchanged",
      "controls_complete_for_authority_population",
      "prior_path_ends_at_decision",
      "dollar_volume_baseline_excludes_current_session",
      "control_scales_end_in_train",
      "control_train_support_complete",
      "raw_n1b_fold_correlations_reproduced",
      "no_forbidden_analysis_surface"
    ),
    status = c(
      if (identical(n1b_status, "PASS_N1B_TO_REPRESENTATION_DISCUSSION")) "PASS" else "FAIL",
      if (length(unique(oos$fold_id)) == 12L) "PASS" else "FAIL",
      if (population_identical && nrow(oos) == nrow(n1b_oos)) "PASS" else "FAIL",
      if (measurement_identical) "PASS" else "FAIL",
      if (controls_complete) "PASS" else "FAIL",
      if (controls_complete && all(oos$prior_path_end_session == oos$decision_session)) "PASS" else "FAIL",
      if (controls_complete && all(oos$dollar_volume_baseline_end_session < oos$decision_session)) "PASS" else "FAIL",
      if (all(oos$control_scale_max_session <= oos$train_end_date, na.rm = TRUE)) "PASS" else "FAIL",
      if (all(train_support$support_ok)) "PASS" else "FAIL",
      if (!anyNA(fold_match) && all(is.finite(raw_difference)) && all(raw_difference <= tolerance)) "PASS" else "FAIL",
      if (identical(as.integer(forbidden_analysis_count), 0L)) "PASS" else "FAIL"
    ),
    detail = c(
      "N1C consumes only the accepted N1B authority packet.",
      "OOS authority remains 2022Q1 through 2024Q4.",
      "Fold/issuer/decision keys and row counts match N1B in the same order.",
      "Frozen news intensity and relative h5 future volatility are byte-for-byte numerical inputs from N1B.",
      "Every accepted N1B OOS row has both frozen OHLCV controls.",
      "The backward h5 path control ends on the decision session.",
      "The 60-session dollar-volume baseline ends before the current decision session.",
      "Every prior-volatility scale is estimated from sessions ending inside TRAIN.",
      "Every issuer-fold has at least 400 finite TRAIN prior-volatility observations and a positive scale.",
      paste0("Maximum absolute fold-correlation difference: ", sprintf("%.3g", max(raw_difference, na.rm = TRUE)), "."),
      "Sentiment, alternate controls, horizons, models, policy, allocation, PnL, and live advice remain absent."
    ),
    stringsAsFactors = FALSE
  )
}

g5_gen54_n1c_representative_pairs <- function(oos, maximum_pairs = 6L) {
  required <- c(
    "fold_id", "issuer_id", "decision_session", "novel_cluster_count",
    "news_intensity_percentile", "high_news_intensity",
    "relative_future_path_volatility_h5", "prior_volatility_rank",
    "dollar_volume_surprise_rank"
  )
  missing <- setdiff(required, names(oos))
  if (length(missing)) {
    g5_gen54_n1c_stop(paste("oos missing for representative pairs:", paste(missing, collapse = ", ")))
  }
  candidates <- list()
  index <- 1L
  for (fold_id in sort(unique(oos$fold_id))) {
    fold <- oos[oos$fold_id == fold_id, , drop = FALSE]
    denominator <- nrow(fold)
    for (issuer in unique(fold$issuer_id)) {
      part <- fold[fold$issuer_id == issuer, , drop = FALSE]
      high_index <- which(part$high_news_intensity)
      no_news_index <- which(part$novel_cluster_count == 0L)
      if (!length(high_index) || !length(no_news_index)) next
      for (i in high_index) {
        distance <- sqrt(
          ((part$prior_volatility_rank[no_news_index] - part$prior_volatility_rank[[i]]) / denominator)^2 +
            ((part$dollar_volume_surprise_rank[no_news_index] - part$dollar_volume_surprise_rank[[i]]) / denominator)^2
        )
        if (!any(is.finite(distance))) next
        j <- no_news_index[[which.min(distance)]]
        candidates[[index]] <- data.frame(
          fold_id = fold_id,
          issuer_id = issuer,
          high_news_session = part$decision_session[[i]],
          comparison_session = part$decision_session[[j]],
          high_novel_cluster_count = part$novel_cluster_count[[i]],
          comparison_novel_cluster_count = part$novel_cluster_count[[j]],
          high_news_intensity_percentile = part$news_intensity_percentile[[i]],
          comparison_news_intensity_percentile = part$news_intensity_percentile[[j]],
          high_relative_prior_volatility = part$relative_prior_path_volatility_h5[[i]],
          comparison_relative_prior_volatility = part$relative_prior_path_volatility_h5[[j]],
          high_dollar_volume_surprise = part$dollar_volume_surprise_1_60[[i]],
          comparison_dollar_volume_surprise = part$dollar_volume_surprise_1_60[[j]],
          control_rank_distance = distance[[which.min(distance)]],
          high_relative_future_volatility = part$relative_future_path_volatility_h5[[i]],
          comparison_relative_future_volatility = part$relative_future_path_volatility_h5[[j]],
          stringsAsFactors = FALSE
        )
        index <- index + 1L
      }
    }
  }
  if (!length(candidates)) return(data.frame())
  pairs <- do.call(rbind, candidates)
  pairs <- pairs[order(pairs$control_rank_distance, pairs$issuer_id, pairs$fold_id), , drop = FALSE]
  pairs <- pairs[!duplicated(pairs$issuer_id), , drop = FALSE]
  pairs <- head(pairs, as.integer(maximum_pairs))
  rownames(pairs) <- NULL
  pairs
}
