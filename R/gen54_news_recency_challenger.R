# Gen5.4 N1D fixed-recency news representation helpers.
#
# N1D compares the frozen equal-count N1B representation with one predeclared
# 24-hour exponential-decay challenger on post-2024 quarterly OOS folds. It
# does not fit a model or compute policy, allocation, PnL, sentiment, source
# weights, embeddings, or live-advice outputs.

g5_gen54_n1d_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message) else stop(message, call. = FALSE)
}

g5_gen54_n1d_cutoff_timestamp <- function(
    decision_session,
    cutoff_time = "17:30:00",
    timezone = "America/New_York") {
  sessions <- as.Date(decision_session)
  if (any(is.na(sessions))) {
    g5_gen54_n1d_stop("decision_session contains missing dates.")
  }
  if (!grepl("^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$", cutoff_time)) {
    g5_gen54_n1d_stop("cutoff_time must use HH:MM:SS.")
  }
  as.POSIXct(
    paste(format(sessions, "%Y-%m-%d"), cutoff_time),
    format = "%Y-%m-%d %H:%M:%S",
    tz = timezone
  )
}

g5_gen54_n1d_attach_recency_mass <- function(
    news,
    half_life_hours = 24,
    cutoff_time = "17:30:00",
    timezone = "America/New_York") {
  half_life_hours <- as.numeric(half_life_hours)
  if (!identical(half_life_hours, 24)) {
    g5_gen54_n1d_stop("N1D freezes the exponential half-life at exactly 24 hours.")
  }
  required_news <- c("panel", "articles", "admissible_associations")
  if (!is.list(news) || !all(required_news %in% names(news))) {
    g5_gen54_n1d_stop("news must be the accepted N1B-style news-panel object.")
  }
  panel <- news$panel
  associations <- news$admissible_associations
  articles <- news$articles
  required_panel <- c(
    "issuer_id", "decision_session", "novel_cluster_count", "news_log1p"
  )
  required_associations <- c(
    "article_id", "issuer_id", "decision_session", "exact_title_cluster_id"
  )
  required_articles <- c("article_id", "updated_at")
  if (length(setdiff(required_panel, names(panel)))) {
    g5_gen54_n1d_stop("news panel lacks frozen N1B measurement columns.")
  }
  if (length(setdiff(required_associations, names(associations)))) {
    g5_gen54_n1d_stop("admissible associations lack issuer, cycle, or cluster columns.")
  }
  if (length(setdiff(required_articles, names(articles)))) {
    g5_gen54_n1d_stop("article authority lacks updated_at.")
  }

  events <- associations[, required_associations, drop = FALSE]
  article_row <- match(events$article_id, articles$article_id)
  if (any(is.na(article_row))) {
    g5_gen54_n1d_stop("An admissible association cannot be reconciled to article authority.")
  }
  events$availability_timestamp <- g5_gen54_news_parse_timestamp(
    articles$updated_at[article_row],
    "updated_at"
  )
  events$decision_cutoff_timestamp <- g5_gen54_n1d_cutoff_timestamp(
    events$decision_session,
    cutoff_time = cutoff_time,
    timezone = timezone
  )
  events$age_hours <- as.numeric(difftime(
    events$decision_cutoff_timestamp,
    events$availability_timestamp,
    units = "hours"
  ))
  if (any(!is.finite(events$age_hours)) || any(events$age_hours < -1e-9)) {
    g5_gen54_n1d_stop("Recency age must be finite and non-negative at the decision cutoff.")
  }
  events$age_hours[abs(events$age_hours) < 1e-9] <- 0
  events$recency_weight <- 2^(-events$age_hours / half_life_hours)
  if (any(!is.finite(events$recency_weight)) ||
      any(events$recency_weight <= 0) ||
      any(events$recency_weight > 1 + 1e-12)) {
    g5_gen54_n1d_stop("Recency weights must be finite in (0, 1].")
  }

  cluster_key <- paste(
    events$issuer_id,
    events$decision_session,
    events$exact_title_cluster_id,
    sep = "\r"
  )
  if (anyDuplicated(cluster_key)) {
    g5_gen54_n1d_stop(
      "Admissible N1D events contain duplicate issuer/session/novel-cluster rows."
    )
  }

  if (nrow(events)) {
    cycle_key <- paste(events$issuer_id, events$decision_session, sep = "\r")
    pieces <- split(seq_len(nrow(events)), cycle_key)
    cycle_rows <- lapply(pieces, function(index) {
      data.frame(
        issuer_id = events$issuer_id[index[[1L]]],
        decision_session = events$decision_session[index[[1L]]],
        recency_cluster_count = length(index),
        recency_mass_24h = sum(events$recency_weight[index]),
        mean_event_age_hours = mean(events$age_hours[index]),
        recency_weighted_mean_age_hours =
          sum(events$age_hours[index] * events$recency_weight[index]) /
            sum(events$recency_weight[index]),
        youngest_event_age_hours = min(events$age_hours[index]),
        oldest_event_age_hours = max(events$age_hours[index]),
        stringsAsFactors = FALSE
      )
    })
    cycles <- do.call(rbind, cycle_rows)
    rownames(cycles) <- NULL
  } else {
    cycles <- data.frame(
      issuer_id = character(),
      decision_session = as.Date(character()),
      recency_cluster_count = integer(),
      recency_mass_24h = numeric(),
      mean_event_age_hours = numeric(),
      recency_weighted_mean_age_hours = numeric(),
      youngest_event_age_hours = numeric(),
      oldest_event_age_hours = numeric(),
      stringsAsFactors = FALSE
    )
  }

  out <- merge(
    panel,
    cycles,
    by = c("issuer_id", "decision_session"),
    all.x = TRUE,
    sort = FALSE
  )
  zero <- is.na(out$recency_cluster_count)
  out$recency_cluster_count[zero] <- 0L
  out$recency_mass_24h[zero] <- 0
  out$recency_log1p_24h <- log1p(out$recency_mass_24h)
  out <- out[order(out$decision_session, out$issuer_id), , drop = FALSE]
  rownames(out) <- NULL
  if (!all(out$recency_cluster_count == out$novel_cluster_count)) {
    g5_gen54_n1d_stop(
      "Recency event counts do not reproduce the frozen equal-count representation."
    )
  }

  list(panel = out, events = events, cycles = cycles)
}

g5_gen54_n1d_evaluate_representations <- function(
    panel,
    folds,
    minimum_train_rows = 400L,
    minimum_nonzero_train_cycles = 20L) {
  required <- c(
    "issuer_id", "decision_session", "execution_session",
    "outcome_end_session", "novel_cluster_count", "news_log1p",
    "recency_mass_24h", "recency_log1p_24h",
    "future_path_volatility_h5"
  )
  missing <- setdiff(required, names(panel))
  if (length(missing)) {
    g5_gen54_n1d_stop(paste("panel missing:", paste(missing, collapse = ", ")))
  }
  required_folds <- c(
    "fold_id", "train_start_date", "train_end_date",
    "oos_start_date", "oos_end_date"
  )
  missing_folds <- setdiff(required_folds, names(folds))
  if (length(missing_folds)) {
    g5_gen54_n1d_stop(paste("folds missing:", paste(missing_folds, collapse = ", ")))
  }

  oos_rows <- list()
  support_rows <- list()
  row_index <- 1L
  support_index <- 1L
  for (fold_no in seq_len(nrow(folds))) {
    fold <- folds[fold_no, , drop = FALSE]
    for (issuer in sort(unique(panel$issuer_id))) {
      issuer_rows <- panel$issuer_id == issuer
      train_keep <- issuer_rows &
        panel$decision_session >= fold$train_start_date &
        panel$decision_session <= fold$train_end_date &
        !is.na(panel$outcome_end_session) &
        panel$outcome_end_session <= fold$train_end_date &
        is.finite(panel$future_path_volatility_h5)
      oos_keep <- issuer_rows &
        panel$decision_session >= fold$oos_start_date &
        panel$decision_session <= fold$oos_end_date &
        !is.na(panel$outcome_end_session) &
        panel$outcome_end_session <= fold$oos_end_date &
        is.finite(panel$future_path_volatility_h5)
      train <- panel[train_keep, , drop = FALSE]
      oos <- panel[oos_keep, , drop = FALSE]
      train_scale <- if (nrow(train)) {
        stats::median(train$future_path_volatility_h5)
      } else {
        NA_real_
      }
      baseline_nonzero <- sum(train$novel_cluster_count > 0)
      recency_nonzero <- sum(train$recency_mass_24h > 0)
      support_ok <- nrow(train) >= as.integer(minimum_train_rows) &&
        baseline_nonzero >= as.integer(minimum_nonzero_train_cycles) &&
        recency_nonzero >= as.integer(minimum_nonzero_train_cycles) &&
        is.finite(train_scale) && train_scale > 0
      support_rows[[support_index]] <- data.frame(
        fold_id = fold$fold_id,
        issuer_id = issuer,
        train_start_date = fold$train_start_date,
        train_end_date = fold$train_end_date,
        train_complete_rows = nrow(train),
        train_nonzero_baseline_cycles = baseline_nonzero,
        train_nonzero_recency_cycles = recency_nonzero,
        train_median_path_volatility_h5 = train_scale,
        minimum_train_rows = as.integer(minimum_train_rows),
        minimum_nonzero_train_cycles =
          as.integer(minimum_nonzero_train_cycles),
        support_ok = support_ok,
        stringsAsFactors = FALSE
      )
      support_index <- support_index + 1L

      if (nrow(oos)) {
        oos$fold_id <- fold$fold_id
        oos$train_start_date <- fold$train_start_date
        oos$train_end_date <- fold$train_end_date
        oos$oos_start_date <- fold$oos_start_date
        oos$oos_end_date <- fold$oos_end_date
        oos$train_complete_rows <- nrow(train)
        oos$train_nonzero_baseline_cycles <- baseline_nonzero
        oos$train_nonzero_recency_cycles <- recency_nonzero
        oos$baseline_news_intensity_percentile <- if (support_ok) {
          g5_gen54_n1b_train_percentile(train$news_log1p, oos$news_log1p)
        } else {
          NA_real_
        }
        oos$recency_news_intensity_percentile <- if (support_ok) {
          g5_gen54_n1b_train_percentile(
            train$recency_log1p_24h,
            oos$recency_log1p_24h
          )
        } else {
          NA_real_
        }
        # Preserve the N1C helper's expected baseline column name.
        oos$news_intensity_percentile <-
          oos$baseline_news_intensity_percentile
        oos$relative_future_path_volatility_h5 <- if (support_ok) {
          oos$future_path_volatility_h5 / train_scale
        } else {
          NA_real_
        }
        oos$normalizer_max_decision_session <- if (nrow(train)) {
          max(train$decision_session)
        } else {
          as.Date(NA)
        }
        oos$outcome_scale_max_end_session <- if (nrow(train)) {
          max(train$outcome_end_session)
        } else {
          as.Date(NA)
        }
        oos_rows[[row_index]] <- oos
        row_index <- row_index + 1L
      }
    }
  }
  oos <- if (length(oos_rows)) do.call(rbind, oos_rows) else data.frame()
  support <- if (length(support_rows)) do.call(rbind, support_rows) else data.frame()
  rownames(oos) <- rownames(support) <- NULL
  list(oos = oos, train_support = support)
}

g5_gen54_n1d_fold_summary <- function(oos, minimum_fold_rows = 20L) {
  required <- c(
    "fold_id", "issuer_id", "baseline_news_intensity_percentile",
    "recency_news_intensity_percentile",
    "relative_future_path_volatility_h5",
    "relative_prior_path_volatility_h5",
    "dollar_volume_surprise_1_60"
  )
  missing <- setdiff(required, names(oos))
  if (length(missing)) {
    g5_gen54_n1d_stop(paste("N1D OOS data missing:", paste(missing, collapse = ", ")))
  }
  rows <- lapply(unique(oos$fold_id), function(fold_id) {
    part <- oos[oos$fold_id == fold_id, , drop = FALSE]
    complete <- is.finite(part$baseline_news_intensity_percentile) &
      is.finite(part$recency_news_intensity_percentile) &
      is.finite(part$relative_future_path_volatility_h5) &
      is.finite(part$relative_prior_path_volatility_h5) &
      is.finite(part$dollar_volume_surprise_1_60)
    part <- part[complete, , drop = FALSE]
    if (nrow(part) < as.integer(minimum_fold_rows)) {
      g5_gen54_n1d_stop(paste("N1D fold has insufficient complete rows:", fold_id))
    }
    controls <- cbind(
      part$relative_prior_path_volatility_h5,
      part$dollar_volume_surprise_1_60
    )
    baseline_partial <- g5_gen54_n1c_partial_spearman(
      part$baseline_news_intensity_percentile,
      part$relative_future_path_volatility_h5,
      controls
    )
    recency_partial <- g5_gen54_n1c_partial_spearman(
      part$recency_news_intensity_percentile,
      part$relative_future_path_volatility_h5,
      controls
    )
    data.frame(
      fold_id = fold_id,
      eligible_observations = nrow(part),
      issuer_count = length(unique(part$issuer_id)),
      baseline_raw_spearman = suppressWarnings(stats::cor(
        part$baseline_news_intensity_percentile,
        part$relative_future_path_volatility_h5,
        method = "spearman"
      )),
      recency_raw_spearman = suppressWarnings(stats::cor(
        part$recency_news_intensity_percentile,
        part$relative_future_path_volatility_h5,
        method = "spearman"
      )),
      baseline_partial_spearman = baseline_partial,
      recency_partial_spearman = recency_partial,
      recency_minus_baseline_partial = recency_partial - baseline_partial,
      baseline_unique_percentiles =
        length(unique(part$baseline_news_intensity_percentile)),
      recency_unique_percentiles =
        length(unique(part$recency_news_intensity_percentile)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

g5_gen54_n1d_verdict <- function(
    fold_summary,
    integrity_passed,
    required_positive_folds = 4L,
    required_improvement_folds = 4L,
    minimum_mean_improvement = 0.01) {
  fold_count <- nrow(fold_summary)
  if (!identical(fold_count, 6L)) {
    g5_gen54_n1d_stop("N1D requires exactly six confirmation folds.")
  }
  mean_recency <- mean(fold_summary$recency_partial_spearman)
  positive_recency <- sum(fold_summary$recency_partial_spearman > 0)
  mean_improvement <- mean(fold_summary$recency_minus_baseline_partial)
  positive_improvement <- sum(
    fold_summary$recency_minus_baseline_partial > 0
  )
  gates <- data.frame(
    gate_id = c(
      "integrity_and_leakage",
      "positive_mean_recency_partial_spearman",
      "positive_recency_in_4_of_6_folds",
      "mean_partial_spearman_improvement_at_least_0_01",
      "positive_improvement_in_4_of_6_folds"
    ),
    passed = c(
      isTRUE(integrity_passed),
      is.finite(mean_recency) && mean_recency > 0,
      positive_recency >= as.integer(required_positive_folds),
      is.finite(mean_improvement) &&
        mean_improvement >= as.numeric(minimum_mean_improvement),
      positive_improvement >= as.integer(required_improvement_folds)
    ),
    value = c(
      if (isTRUE(integrity_passed)) "PASS" else "FAIL",
      sprintf("%.6f", mean_recency),
      as.character(positive_recency),
      sprintf("%.6f", mean_improvement),
      as.character(positive_improvement)
    ),
    threshold = c(
      "PASS",
      "> 0",
      ">= 4",
      ">= 0.01",
      ">= 4"
    ),
    stringsAsFactors = FALSE
  )
  list(
    passed = all(gates$passed),
    gates = gates,
    mean_baseline_partial_spearman =
      mean(fold_summary$baseline_partial_spearman),
    mean_recency_partial_spearman = mean_recency,
    positive_recency_folds = positive_recency,
    mean_partial_spearman_improvement = mean_improvement,
    positive_improvement_folds = positive_improvement
  )
}

g5_gen54_n1d_representative_timing_pairs <- function(
    oos,
    maximum_pairs = 6L) {
  required <- c(
    "fold_id", "issuer_id", "decision_session", "novel_cluster_count",
    "recency_mass_24h", "recency_weighted_mean_age_hours",
    "relative_future_path_volatility_h5"
  )
  missing <- setdiff(required, names(oos))
  if (length(missing)) {
    g5_gen54_n1d_stop(paste("timing-pair data missing:", paste(missing, collapse = ", ")))
  }
  eligible <- oos[
    oos$novel_cluster_count > 0 &
      is.finite(oos$recency_mass_24h) &
      is.finite(oos$relative_future_path_volatility_h5),
    ,
    drop = FALSE
  ]
  if (!nrow(eligible)) return(data.frame())
  key <- paste(
    eligible$fold_id,
    eligible$issuer_id,
    eligible$novel_cluster_count,
    sep = "\r"
  )
  candidates <- lapply(split(seq_len(nrow(eligible)), key), function(index) {
    if (length(index) < 2L) return(NULL)
    values <- eligible$recency_mass_24h[index]
    older <- index[[which.min(values)]]
    fresher <- index[[which.max(values)]]
    spread <- values[[which.max(values)]] - values[[which.min(values)]]
    if (!is.finite(spread) || spread <= 0) return(NULL)
    data.frame(
      fold_id = eligible$fold_id[[older]],
      issuer_id = eligible$issuer_id[[older]],
      novel_cluster_count = eligible$novel_cluster_count[[older]],
      recency_mass_spread = spread,
      older_decision_session = eligible$decision_session[[older]],
      older_recency_mass = eligible$recency_mass_24h[[older]],
      older_weighted_mean_age_hours =
        eligible$recency_weighted_mean_age_hours[[older]],
      older_relative_future_volatility =
        eligible$relative_future_path_volatility_h5[[older]],
      fresher_decision_session = eligible$decision_session[[fresher]],
      fresher_recency_mass = eligible$recency_mass_24h[[fresher]],
      fresher_weighted_mean_age_hours =
        eligible$recency_weighted_mean_age_hours[[fresher]],
      fresher_relative_future_volatility =
        eligible$relative_future_path_volatility_h5[[fresher]],
      stringsAsFactors = FALSE
    )
  })
  candidates <- candidates[!vapply(candidates, is.null, logical(1L))]
  if (!length(candidates)) return(data.frame())
  candidates <- do.call(rbind, candidates)
  candidates <- candidates[
    order(-candidates$recency_mass_spread, candidates$fold_id, candidates$issuer_id),
    ,
    drop = FALSE
  ]
  selected <- integer()
  used_issuers <- character()
  for (row in seq_len(nrow(candidates))) {
    if (candidates$issuer_id[[row]] %in% used_issuers) next
    selected <- c(selected, row)
    used_issuers <- c(used_issuers, candidates$issuer_id[[row]])
    if (length(selected) >= as.integer(maximum_pairs)) break
  }
  if (length(selected) < min(as.integer(maximum_pairs), nrow(candidates))) {
    remaining <- setdiff(seq_len(nrow(candidates)), selected)
    selected <- c(
      selected,
      head(remaining, as.integer(maximum_pairs) - length(selected))
    )
  }
  out <- candidates[selected, , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_gen54_n1d_leakage_audit <- function(
    result,
    fold_summary,
    recency_events,
    expected_fold_ids,
    half_life_hours,
    coverage_passed,
    query_health_passed,
    forbidden_analysis_count = 0L) {
  oos <- result$oos
  support <- result$train_support
  checks <- c(
    exact_confirmation_folds =
      identical(as.character(fold_summary$fold_id), as.character(expected_fold_ids)),
    confirmation_begins_after_2024 =
      nrow(oos) > 0L && min(oos$oos_start_date) >= as.Date("2025-01-01"),
    fixed_24_hour_half_life = identical(as.numeric(half_life_hours), 24),
    nonnegative_availability_ages =
      nrow(recency_events) > 0L &&
        all(is.finite(recency_events$age_hours)) &&
        all(recency_events$age_hours >= 0),
    frozen_count_reproduced =
      nrow(oos) > 0L &&
        all(oos$recency_cluster_count == oos$novel_cluster_count),
    train_representation_support_complete =
      nrow(support) == 24L * length(expected_fold_ids) &&
        all(support$support_ok),
    normalizers_end_in_train =
      all(oos$normalizer_max_decision_session <= oos$train_end_date),
    outcome_scales_end_in_train =
      all(oos$outcome_scale_max_end_session <= oos$train_end_date),
    outcomes_end_inside_oos_fold =
      all(oos$outcome_end_session <= oos$oos_end_date),
    prior_control_ends_at_decision =
      all(oos$prior_path_end_session == oos$decision_session),
    dollar_volume_baseline_excludes_current =
      all(oos$dollar_volume_baseline_end_session < oos$decision_session),
    control_scales_end_in_train =
      all(oos$control_scale_max_session <= oos$train_end_date),
    confirmation_coverage_passed = isTRUE(coverage_passed),
    adjusted_bar_query_health_passed = isTRUE(query_health_passed),
    no_forbidden_analysis_surface =
      identical(as.integer(forbidden_analysis_count), 0L)
  )
  details <- c(
    paste("Confirmation folds:", paste(expected_fold_ids, collapse = ", ")),
    "Every evaluated OOS row belongs to 2025Q1 through 2026Q2.",
    "The only challenger uses a fixed 24-hour exponential half-life.",
    "Historical availability uses updated_at and never falls after the assigned cutoff.",
    "Every recency cycle reproduces the frozen novel-cluster count.",
    "All 24 issuers satisfy TRAIN row and nonzero-cycle support in all six folds.",
    "Issuer-local representation ECDFs are frozen before each OOS fold.",
    "Future-volatility scales use only outcomes ending inside TRAIN.",
    "No future h5 path crosses its quarterly OOS boundary.",
    "The prior-h5 control ends on the decision session.",
    "The 60-session dollar-volume baseline excludes the current session.",
    "Prior-volatility control scales end inside TRAIN.",
    "All 24 issuers have admissible novel-news coverage in every confirmation quarter.",
    "Adjusted daily OHLCV covers the bounded confirmation and lookback window.",
    "Sentiment, source weights, alternate decays, models, policy, allocation, PnL, and live advice remain absent."
  )
  data.frame(
    check_id = names(checks),
    status = ifelse(checks, "PASS", "FAIL"),
    detail = details,
    stringsAsFactors = FALSE
  )
}
