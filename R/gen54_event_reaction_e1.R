g5_gen54_e1_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message) else stop(message, call. = FALSE)
}

g5_gen54_e1_require <- function(x, columns, label) {
  missing <- setdiff(columns, names(x))
  if (length(missing)) {
    g5_gen54_e1_stop(paste(label, "missing:", paste(missing, collapse = ", ")))
  }
}

g5_gen54_e1_bar_values <- function(bars, symbols, dates, column) {
  key <- paste(bars$issuer_id, as.Date(bars$session_date), sep = "\r")
  wanted <- paste(symbols, as.Date(dates), sep = "\r")
  bars[[column]][match(wanted, key)]
}

g5_gen54_e1_spy_values <- function(spy_bars, dates, column) {
  spy_bars[[column]][match(as.Date(dates), as.Date(spy_bars$session_date))]
}

g5_gen54_e1_attach_price_measurements <- function(
    panel,
    issuer_bars,
    spy_bars,
    session_dates,
    outcome_horizon = 5L) {
  outcome_horizon <- as.integer(outcome_horizon)
  if (!identical(outcome_horizon, 5L)) {
    g5_gen54_e1_stop("E1 freezes the continuation horizon at five sessions.")
  }
  g5_gen54_e1_require(
    panel,
    c(
      "issuer_id", "decision_session", "execution_session", "fold_id",
      "oos_end_date", "novel_cluster_count",
      "baseline_news_intensity_percentile"
    ),
    "panel"
  )
  g5_gen54_e1_require(
    issuer_bars,
    c("issuer_id", "session_date", "open", "close"),
    "issuer_bars"
  )
  g5_gen54_e1_require(
    spy_bars,
    c("session_date", "open", "close"),
    "spy_bars"
  )

  sessions <- sort(unique(as.Date(session_dates)))
  out <- panel
  out$decision_session <- as.Date(out$decision_session)
  out$reaction_session <- as.Date(out$execution_session)
  reaction_index <- match(out$reaction_session, sessions)
  entry_index <- reaction_index + 1L
  endpoint_index <- entry_index + outcome_horizon
  out$entry_session <- as.Date(NA)
  out$outcome_end_session_e1 <- as.Date(NA)
  valid_entry <- !is.na(entry_index) & entry_index <= length(sessions)
  valid_endpoint <- !is.na(endpoint_index) & endpoint_index <= length(sessions)
  out$entry_session[valid_entry] <- sessions[entry_index[valid_entry]]
  out$outcome_end_session_e1[valid_endpoint] <- sessions[endpoint_index[valid_endpoint]]

  out$issuer_decision_close <- g5_gen54_e1_bar_values(
    issuer_bars, out$issuer_id, out$decision_session, "close"
  )
  out$issuer_reaction_open <- g5_gen54_e1_bar_values(
    issuer_bars, out$issuer_id, out$reaction_session, "open"
  )
  out$issuer_reaction_close <- g5_gen54_e1_bar_values(
    issuer_bars, out$issuer_id, out$reaction_session, "close"
  )
  out$issuer_entry_open <- g5_gen54_e1_bar_values(
    issuer_bars, out$issuer_id, out$entry_session, "open"
  )
  out$issuer_outcome_end_open <- g5_gen54_e1_bar_values(
    issuer_bars, out$issuer_id, out$outcome_end_session_e1, "open"
  )
  out$spy_decision_close <- g5_gen54_e1_spy_values(
    spy_bars, out$decision_session, "close"
  )
  out$spy_reaction_open <- g5_gen54_e1_spy_values(
    spy_bars, out$reaction_session, "open"
  )
  out$spy_reaction_close <- g5_gen54_e1_spy_values(
    spy_bars, out$reaction_session, "close"
  )
  out$spy_entry_open <- g5_gen54_e1_spy_values(
    spy_bars, out$entry_session, "open"
  )
  out$spy_outcome_end_open <- g5_gen54_e1_spy_values(
    spy_bars, out$outcome_end_session_e1, "open"
  )

  price_columns <- c(
    "issuer_decision_close", "issuer_reaction_open", "issuer_reaction_close",
    "issuer_entry_open", "issuer_outcome_end_open", "spy_decision_close",
    "spy_reaction_open", "spy_reaction_close", "spy_entry_open",
    "spy_outcome_end_open"
  )
  positive_prices <- Reduce(
    `&`,
    lapply(price_columns, function(column) {
      is.finite(out[[column]]) & out[[column]] > 0
    })
  )
  out$price_path_complete <- positive_prices
  out$overnight_excess_log_return <- ifelse(
    positive_prices,
    log(out$issuer_reaction_open / out$issuer_decision_close) -
      log(out$spy_reaction_open / out$spy_decision_close),
    NA_real_
  )
  out$intraday_excess_log_return <- ifelse(
    positive_prices,
    log(out$issuer_reaction_close / out$issuer_reaction_open) -
      log(out$spy_reaction_close / out$spy_reaction_open),
    NA_real_
  )
  out$continuation_excess_h5 <- ifelse(
    positive_prices,
    log(out$issuer_outcome_end_open / out$issuer_entry_open) -
      log(out$spy_outcome_end_open / out$spy_entry_open),
    NA_real_
  )
  out$outcome_inside_oos <- !is.na(out$outcome_end_session_e1) &
    out$outcome_end_session_e1 <= as.Date(out$oos_end_date)
  out
}

g5_gen54_e1_reaction_history <- function(
    issuer_bars,
    spy_bars,
    session_dates) {
  g5_gen54_e1_require(
    issuer_bars,
    c("issuer_id", "session_date", "open", "close"),
    "issuer_bars"
  )
  g5_gen54_e1_require(
    spy_bars,
    c("session_date", "open", "close"),
    "spy_bars"
  )
  sessions <- sort(unique(as.Date(session_dates)))
  if (length(sessions) < 2L) g5_gen54_e1_stop("At least two sessions are required.")
  decision <- sessions[-length(sessions)]
  reaction <- sessions[-1L]
  pieces <- lapply(sort(unique(issuer_bars$issuer_id)), function(issuer) {
    x <- data.frame(
      issuer_id = issuer,
      decision_session = decision,
      reaction_session = reaction,
      stringsAsFactors = FALSE
    )
    x$issuer_decision_close <- g5_gen54_e1_bar_values(
      issuer_bars, x$issuer_id, x$decision_session, "close"
    )
    x$issuer_reaction_open <- g5_gen54_e1_bar_values(
      issuer_bars, x$issuer_id, x$reaction_session, "open"
    )
    x$issuer_reaction_close <- g5_gen54_e1_bar_values(
      issuer_bars, x$issuer_id, x$reaction_session, "close"
    )
    x$spy_decision_close <- g5_gen54_e1_spy_values(
      spy_bars, x$decision_session, "close"
    )
    x$spy_reaction_open <- g5_gen54_e1_spy_values(
      spy_bars, x$reaction_session, "open"
    )
    x$spy_reaction_close <- g5_gen54_e1_spy_values(
      spy_bars, x$reaction_session, "close"
    )
    complete <- Reduce(`&`, lapply(
      c(
        "issuer_decision_close", "issuer_reaction_open",
        "issuer_reaction_close", "spy_decision_close",
        "spy_reaction_open", "spy_reaction_close"
      ),
      function(column) is.finite(x[[column]]) & x[[column]] > 0
    ))
    x$overnight_excess_log_return <- ifelse(
      complete,
      log(x$issuer_reaction_open / x$issuer_decision_close) -
        log(x$spy_reaction_open / x$spy_decision_close),
      NA_real_
    )
    x$intraday_excess_log_return <- ifelse(
      complete,
      log(x$issuer_reaction_close / x$issuer_reaction_open) -
        log(x$spy_reaction_close / x$spy_reaction_open),
      NA_real_
    )
    x
  })
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  out
}

g5_gen54_e1_attach_train_reaction_scales <- function(
    panel,
    reaction_history,
    folds,
    minimum_train_rows = 100L) {
  g5_gen54_e1_require(
    panel,
    c(
      "issuer_id", "fold_id", "overnight_excess_log_return",
      "intraday_excess_log_return"
    ),
    "panel"
  )
  g5_gen54_e1_require(
    reaction_history,
    c(
      "issuer_id", "decision_session", "reaction_session",
      "overnight_excess_log_return", "intraday_excess_log_return"
    ),
    "reaction_history"
  )
  g5_gen54_e1_require(
    folds,
    c("fold_id", "train_start_date", "train_end_date", "oos_start_date"),
    "folds"
  )

  scales <- list()
  index <- 1L
  for (fold_no in seq_len(nrow(folds))) {
    fold <- folds[fold_no, , drop = FALSE]
    for (issuer in sort(unique(panel$issuer_id))) {
      keep <- reaction_history$issuer_id == issuer &
        reaction_history$decision_session >= as.Date(fold$train_start_date) &
        reaction_history$reaction_session <= as.Date(fold$train_end_date) &
        is.finite(reaction_history$overnight_excess_log_return) &
        is.finite(reaction_history$intraday_excess_log_return)
      train <- reaction_history[keep, , drop = FALSE]
      overnight_mad <- if (nrow(train)) {
        stats::mad(train$overnight_excess_log_return, constant = 1.4826)
      } else {
        NA_real_
      }
      intraday_mad <- if (nrow(train)) {
        stats::mad(train$intraday_excess_log_return, constant = 1.4826)
      } else {
        NA_real_
      }
      support_ok <- nrow(train) >= as.integer(minimum_train_rows) &&
        is.finite(overnight_mad) && overnight_mad > 0 &&
        is.finite(intraday_mad) && intraday_mad > 0
      scales[[index]] <- data.frame(
        fold_id = as.character(fold$fold_id),
        issuer_id = issuer,
        train_start_date = as.Date(fold$train_start_date),
        train_end_date = as.Date(fold$train_end_date),
        train_reaction_rows = nrow(train),
        overnight_train_median = if (nrow(train)) {
          stats::median(train$overnight_excess_log_return)
        } else {
          NA_real_
        },
        overnight_train_mad = overnight_mad,
        intraday_train_median = if (nrow(train)) {
          stats::median(train$intraday_excess_log_return)
        } else {
          NA_real_
        },
        intraday_train_mad = intraday_mad,
        reaction_scale_max_session = if (nrow(train)) {
          max(train$reaction_session)
        } else {
          as.Date(NA)
        },
        minimum_train_rows = as.integer(minimum_train_rows),
        support_ok = support_ok,
        stringsAsFactors = FALSE
      )
      index <- index + 1L
    }
  }
  scale_table <- do.call(rbind, scales)
  out <- merge(
    panel,
    scale_table,
    by = c("fold_id", "issuer_id"),
    all.x = TRUE,
    sort = FALSE
  )
  out$overnight_reaction_z <- (
    out$overnight_excess_log_return - out$overnight_train_median
  ) / out$overnight_train_mad
  out$intraday_reaction_z <- (
    out$intraday_excess_log_return - out$intraday_train_median
  ) / out$intraday_train_mad
  out <- out[order(out$decision_session, out$issuer_id), , drop = FALSE]
  rownames(out) <- rownames(scale_table) <- NULL
  list(panel = out, scales = scale_table)
}

g5_gen54_e1_classify <- function(panel, high_percentile = 0.80) {
  out <- panel
  out$unusual_information_cycle <- out$novel_cluster_count > 0 &
    is.finite(out$baseline_news_intensity_percentile) &
    out$baseline_news_intensity_percentile >= high_percentile
  out$positive_overnight_reaction <- is.finite(out$overnight_excess_log_return) &
    out$overnight_excess_log_return > 0
  out$positive_intraday_confirmation <- is.finite(out$intraday_excess_log_return) &
    out$intraday_excess_log_return > 0
  out$raw_signal <- out$unusual_information_cycle &
    out$positive_overnight_reaction &
    out$positive_intraday_confirmation &
    out$price_path_complete &
    out$outcome_inside_oos &
    out$support_ok
  out$control_candidate <- out$novel_cluster_count == 0 &
    out$positive_overnight_reaction &
    out$positive_intraday_confirmation &
    out$price_path_complete &
    out$outcome_inside_oos &
    out$support_ok
  out
}

g5_gen54_e1_apply_overlap_embargo <- function(panel) {
  out <- panel
  out$overlap_retained <- FALSE
  out$overlap_disposition <- ifelse(out$raw_signal, "pending", "not_signal")
  for (issuer in sort(unique(out$issuer_id))) {
    rows <- which(out$issuer_id == issuer & out$raw_signal)
    rows <- rows[order(out$entry_session[rows], out$decision_session[rows])]
    last_endpoint <- as.Date(NA)
    for (row in rows) {
      if (is.na(last_endpoint) || out$entry_session[[row]] >= last_endpoint) {
        out$overlap_retained[[row]] <- TRUE
        out$overlap_disposition[[row]] <- "retained"
        last_endpoint <- out$outcome_end_session_e1[[row]]
      } else {
        out$overlap_disposition[[row]] <- "suppressed_before_prior_endpoint"
      }
    }
  }
  out
}

g5_gen54_e1_match_controls <- function(panel, caliper = 0.50) {
  signals <- panel[panel$overlap_retained, , drop = FALSE]
  controls <- panel[panel$control_candidate, , drop = FALSE]
  matches <- vector("list", nrow(signals))
  for (i in seq_len(nrow(signals))) {
    signal <- signals[i, , drop = FALSE]
    candidates <- controls[
      controls$issuer_id == signal$issuer_id &
        controls$fold_id == signal$fold_id,
      ,
      drop = FALSE
    ]
    if (nrow(candidates)) {
      overnight_difference <- abs(
        candidates$overnight_reaction_z - signal$overnight_reaction_z
      )
      intraday_difference <- abs(
        candidates$intraday_reaction_z - signal$intraday_reaction_z
      )
      distance <- sqrt(overnight_difference^2 + intraday_difference^2)
      eligible <- is.finite(distance) &
        overnight_difference <= caliper &
        intraday_difference <= caliper
      candidates <- candidates[eligible, , drop = FALSE]
      overnight_difference <- overnight_difference[eligible]
      intraday_difference <- intraday_difference[eligible]
      distance <- distance[eligible]
    }
    if (!nrow(candidates)) {
      matches[[i]] <- data.frame(
        signal_id = paste0(
          "e1_", signal$issuer_id, "_",
          format(signal$decision_session, "%Y%m%d")
        ),
        fold_id = signal$fold_id,
        issuer_id = signal$issuer_id,
        signal_decision_session = signal$decision_session,
        signal_entry_session = signal$entry_session,
        signal_outcome_end_session = signal$outcome_end_session_e1,
        signal_news_percentile = signal$baseline_news_intensity_percentile,
        signal_novel_cluster_count = signal$novel_cluster_count,
        signal_overnight_excess = signal$overnight_excess_log_return,
        signal_intraday_excess = signal$intraday_excess_log_return,
        signal_continuation_excess_h5 = signal$continuation_excess_h5,
        matched = FALSE,
        control_fold_id = NA_character_,
        control_issuer_id = NA_character_,
        control_decision_session = as.Date(NA),
        control_novel_cluster_count = NA_integer_,
        control_overnight_excess = NA_real_,
        control_intraday_excess = NA_real_,
        control_continuation_excess_h5 = NA_real_,
        overnight_z_difference = NA_real_,
        intraday_z_difference = NA_real_,
        match_distance = NA_real_,
        matched_difference_h5 = NA_real_,
        stringsAsFactors = FALSE
      )
      next
    }
    order_rows <- order(distance, candidates$decision_session)
    chosen <- candidates[order_rows[[1L]], , drop = FALSE]
    chosen_index <- order_rows[[1L]]
    matches[[i]] <- data.frame(
      signal_id = paste0(
        "e1_", signal$issuer_id, "_",
        format(signal$decision_session, "%Y%m%d")
      ),
      fold_id = signal$fold_id,
      issuer_id = signal$issuer_id,
      signal_decision_session = signal$decision_session,
      signal_entry_session = signal$entry_session,
      signal_outcome_end_session = signal$outcome_end_session_e1,
      signal_news_percentile = signal$baseline_news_intensity_percentile,
      signal_novel_cluster_count = signal$novel_cluster_count,
      signal_overnight_excess = signal$overnight_excess_log_return,
      signal_intraday_excess = signal$intraday_excess_log_return,
      signal_continuation_excess_h5 = signal$continuation_excess_h5,
      matched = TRUE,
      control_fold_id = chosen$fold_id,
      control_issuer_id = chosen$issuer_id,
      control_decision_session = chosen$decision_session,
      control_novel_cluster_count = chosen$novel_cluster_count,
      control_overnight_excess = chosen$overnight_excess_log_return,
      control_intraday_excess = chosen$intraday_excess_log_return,
      control_continuation_excess_h5 = chosen$continuation_excess_h5,
      overnight_z_difference = overnight_difference[[chosen_index]],
      intraday_z_difference = intraday_difference[[chosen_index]],
      match_distance = distance[[chosen_index]],
      matched_difference_h5 =
        signal$continuation_excess_h5 - chosen$continuation_excess_h5,
      stringsAsFactors = FALSE
    )
  }
  if (!length(matches)) {
    return(data.frame())
  }
  out <- do.call(rbind, matches)
  rownames(out) <- NULL
  out
}

g5_gen54_e1_fold_summary <- function(matches, expected_folds) {
  folds <- as.character(expected_folds)
  pieces <- lapply(folds, function(fold_id) {
    part <- matches[matches$fold_id == fold_id, , drop = FALSE]
    matched <- part[part$matched, , drop = FALSE]
    data.frame(
      fold_id = fold_id,
      retained_signals = nrow(part),
      matched_signals = nrow(matched),
      matched_share = if (nrow(part)) nrow(matched) / nrow(part) else NA_real_,
      issuer_count = length(unique(part$issuer_id)),
      mean_signal_continuation_excess_h5 = if (nrow(matched)) {
        mean(matched$signal_continuation_excess_h5)
      } else {
        NA_real_
      },
      mean_control_continuation_excess_h5 = if (nrow(matched)) {
        mean(matched$control_continuation_excess_h5)
      } else {
        NA_real_
      },
      mean_matched_difference_h5 = if (nrow(matched)) {
        mean(matched$matched_difference_h5)
      } else {
        NA_real_
      },
      median_matched_difference_h5 = if (nrow(matched)) {
        stats::median(matched$matched_difference_h5)
      } else {
        NA_real_
      },
      positive_signal_share = if (nrow(matched)) {
        mean(matched$signal_continuation_excess_h5 > 0)
      } else {
        NA_real_
      },
      positive_matched_difference_share = if (nrow(matched)) {
        mean(matched$matched_difference_h5 > 0)
      } else {
        NA_real_
      },
      median_match_distance = if (nrow(matched)) {
        stats::median(matched$match_distance)
      } else {
        NA_real_
      },
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  out
}

g5_gen54_e1_integrity_audit <- function(
    panel,
    matches,
    scales,
    e0_passed,
    n1d_passed,
    counts_reproduced,
    bar_coverage_passed,
    forbidden_surface_count = 0L,
    minimum_signals = 20L,
    minimum_issuers = 8L,
    minimum_quarters = 4L,
    minimum_match_share = 0.70) {
  signals <- panel[panel$overlap_retained, , drop = FALSE]
  matched <- matches[matches$matched, , drop = FALSE]
  signal_support <- nrow(signals) >= minimum_signals &&
    length(unique(signals$issuer_id)) >= minimum_issuers &&
    length(unique(signals$fold_id)) >= minimum_quarters
  match_share <- if (nrow(signals)) nrow(matched) / nrow(signals) else 0
  overlap_ok <- all(vapply(
    split(signals, signals$issuer_id),
    function(part) {
      if (nrow(part) < 2L) return(TRUE)
      part <- part[order(part$entry_session), , drop = FALSE]
      all(part$entry_session[-1L] >= part$outcome_end_session_e1[-nrow(part)])
    },
    logical(1L)
  ))
  controls_ok <- !nrow(matched) || all(
    matched$control_fold_id == matched$fold_id &
      matched$control_issuer_id == matched$issuer_id &
      matched$control_novel_cluster_count == 0 &
      matched$control_overnight_excess > 0 &
      matched$control_intraday_excess > 0
  )
  checks <- data.frame(
    check_id = c(
      "e0_integrity_passed",
      "n1d_leakage_authority_passed",
      "e0_n1d_counts_reproduced",
      "adjusted_bar_coverage_passed",
      "news_normalizers_end_before_oos",
      "reaction_after_decision",
      "entry_after_confirmation",
      "outcomes_inside_oos",
      "retained_signals_follow_frozen_rule",
      "issuer_overlap_embargo",
      "matched_controls_follow_frozen_rule",
      "matching_scales_train_only",
      "minimum_signal_support",
      "minimum_match_share",
      "no_forbidden_surface"
    ),
    status = c(
      e0_passed,
      n1d_passed,
      counts_reproduced,
      bar_coverage_passed,
      all(panel$normalizer_max_decision_session < panel$oos_start_date),
      all(panel$reaction_session > panel$decision_session),
      all(panel$entry_session > panel$reaction_session),
      all(!panel$raw_signal | panel$outcome_inside_oos),
      !nrow(signals) || all(
        signals$unusual_information_cycle &
          signals$positive_overnight_reaction &
          signals$positive_intraday_confirmation
      ),
      overlap_ok,
      controls_ok,
      all(scales$support_ok &
        scales$reaction_scale_max_session <= scales$train_end_date),
      signal_support,
      match_share >= minimum_match_share,
      forbidden_surface_count == 0L
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$status, "PASS", "FAIL")
  checks$detail <- c(
    "Every E0 construction gate remains PASS.",
    "Every inherited N1D leakage gate remains PASS.",
    "Every boundary-purged positive N1D OOS row matches E0 cycle authority.",
    "Issuer and SPY adjusted bars cover the bounded E1 window.",
    "Issuer-local news percentiles are inherited from prior TRAIN only.",
    "The reaction session follows the information-cycle decision.",
    "Hypothetical entry follows the confirmation close.",
    "Only outcomes ending inside the quarterly OOS boundary are eligible.",
    "Signals require TRAIN-p80 news, positive overnight, and positive intraday reaction.",
    "Retained issuer signals do not begin before a prior endpoint.",
    "Admitted controls have the frozen positive price pattern; zero-news and identity checks are enforced during matching.",
    "Reaction medians and MADs end inside TRAIN.",
    paste0(
      nrow(signals), " signals; ",
      length(unique(signals$issuer_id)), " issuers; ",
      length(unique(signals$fold_id)), " quarters."
    ),
    paste0(sprintf("%.1f%%", 100 * match_share), " retained signals matched."),
    "No sentiment, model, threshold search, portfolio, PnL, allocation, or live change."
  )
  checks
}
