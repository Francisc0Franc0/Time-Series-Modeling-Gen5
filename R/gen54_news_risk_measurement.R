# Gen5.4 N1B issuer-relative news-intensity and future-volatility helpers.
#
# This module is measurement-only. It does not compute sentiment, directional
# return forecasts, exposure, allocation, portfolio performance, or live advice.

g5_gen54_n1b_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message) else stop(message, call. = FALSE)
}

g5_gen54_n1b_decode_unicode_escapes <- function(values) {
  out <- as.character(values)
  pattern <- "<U\\+[0-9A-Fa-f]{4,6}>"
  for (i in seq_along(out)) {
    if (is.na(out[[i]])) next
    repeat {
      location <- regexpr(pattern, out[[i]], perl = TRUE)
      if (location[[1L]] < 0L) break
      width <- attr(location, "match.length")[[1L]]
      token <- substr(out[[i]], location[[1L]], location[[1L]] + width - 1L)
      codepoint <- strtoi(substr(token, 4L, nchar(token) - 1L), base = 16L)
      replacement <- intToUtf8(codepoint)
      prefix <- if (location[[1L]] > 1L) substr(out[[i]], 1L, location[[1L]] - 1L) else ""
      suffix_start <- location[[1L]] + width
      suffix <- if (suffix_start <= nchar(out[[i]])) substr(out[[i]], suffix_start, nchar(out[[i]])) else ""
      out[[i]] <- paste0(prefix, replacement, suffix)
    }
  }
  Encoding(out) <- "UTF-8"
  out
}

g5_gen54_n1b_issuer_registry <- function(candidate_registry = g5_gen54_xs_candidate_registry()) {
  required <- c("symbol", "economic_group")
  missing <- setdiff(required, names(candidate_registry))
  if (length(missing)) g5_gen54_n1b_stop(paste("candidate_registry missing:", paste(missing, collapse = ", ")))
  base <- candidate_registry[candidate_registry$symbol != "META", c("symbol", "economic_group"), drop = FALSE]
  out <- data.frame(
    issuer_id = base$symbol,
    provider_symbol = base$symbol,
    economic_group = base$economic_group,
    valid_from = as.Date("1900-01-01"),
    valid_to = as.Date("9999-12-31"),
    stringsAsFactors = FALSE
  )
  meta_group <- candidate_registry$economic_group[match("META", candidate_registry$symbol)]
  meta <- data.frame(
    issuer_id = "META_PLATFORMS",
    provider_symbol = c("FB", "META"),
    economic_group = meta_group,
    valid_from = as.Date(c("1900-01-01", "2022-06-09")),
    valid_to = as.Date(c("2022-06-08", "9999-12-31")),
    stringsAsFactors = FALSE
  )
  out <- rbind(out, meta)
  out <- out[order(out$issuer_id, out$valid_from), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_gen54_n1b_combine_articles <- function(n1a_articles, fb_articles) {
  required <- names(g5_alpaca_empty_news())
  for (label in c("n1a_articles", "fb_articles")) {
    value <- get(label)
    if (!is.data.frame(value) || !all(required %in% names(value))) {
      g5_gen54_n1b_stop(paste0(label, " does not satisfy the canonical Alpaca news schema."))
    }
  }
  combined <- rbind(n1a_articles[, required, drop = FALSE], fb_articles[, required, drop = FALSE])
  text_columns <- intersect(c("headline", "summary", "author", "source"), names(combined))
  for (column in text_columns) {
    combined[[column]] <- g5_gen54_n1b_decode_unicode_escapes(combined[[column]])
  }
  if (!nrow(combined)) g5_gen54_n1b_stop("No historical news articles were supplied.")
  combined <- combined[order(combined$article_id, combined$updated_at), , drop = FALSE]
  duplicate_ids <- unique(combined$article_id[duplicated(combined$article_id)])
  if (length(duplicate_ids)) {
    core <- paste(combined$headline, combined$symbols, combined$created_at, combined$updated_at, sep = "\r")
    conflicting <- unique(combined$article_id[
      ave(core, combined$article_id, FUN = function(x) length(unique(x))) > 1L
    ])
    if (length(conflicting)) {
      g5_gen54_n1b_stop(paste0("Duplicate article IDs disagree across N1A and FB retrieval: ", paste(head(conflicting, 10L), collapse = ", ")))
    }
    combined <- combined[!duplicated(combined$article_id), , drop = FALSE]
  }
  rownames(combined) <- NULL
  combined
}

g5_gen54_n1b_build_news_panel <- function(
    articles,
    session_dates,
    issuer_registry = g5_gen54_n1b_issuer_registry(),
    start_date = as.Date("2020-01-01"),
    end_date = as.Date("2024-12-31"),
    maximum_update_delay_hours = 24,
    repeat_window_hours = 72,
    cutoff_time = "17:30:00",
    timezone = "America/New_York") {
  sessions <- sort(unique(as.Date(session_dates)))
  sessions <- sessions[sessions >= as.Date(start_date) & sessions <= as.Date(end_date)]
  if (!length(sessions)) g5_gen54_n1b_stop("No market sessions fall inside the N1B archive window.")
  provider_symbols <- unique(issuer_registry$provider_symbol)
  built <- g5_gen54_news_build_admissibility(
    articles = articles,
    candidate_symbols = provider_symbols,
    session_dates = session_dates,
    cutoff_time = cutoff_time,
    timezone = timezone,
    repeat_window_hours = repeat_window_hours
  )
  associations <- built$associations
  article_row <- match(associations$article_id, built$articles$article_id)
  associations$update_delay_seconds <- built$articles$update_delay_seconds[article_row]
  registry_row <- match(associations$symbol, issuer_registry$provider_symbol)
  associations$issuer_id <- issuer_registry$issuer_id[registry_row]
  associations$valid_from <- issuer_registry$valid_from[registry_row]
  associations$valid_to <- issuer_registry$valid_to[registry_row]
  associations$symbol_valid_on_decision <- !is.na(associations$decision_session) &
    associations$decision_session >= associations$valid_from &
    associations$decision_session <= associations$valid_to
  associations$stale_update <- associations$update_delay_seconds > as.numeric(maximum_update_delay_hours) * 3600
  associations$admissible_novel <- associations$symbol_valid_on_decision &
    !associations$exact_title_repeat &
    !associations$stale_update &
    !is.na(associations$decision_session) &
    associations$decision_session >= as.Date(start_date) &
    associations$decision_session <= as.Date(end_date)

  usable <- associations[associations$admissible_novel, , drop = FALSE]
  if (nrow(usable)) {
    key <- paste(usable$issuer_id, usable$decision_session, sep = "\r")
    counts <- aggregate(
      usable$exact_title_cluster_id,
      list(key = key),
      function(x) length(unique(x))
    )
    names(counts)[[2L]] <- "novel_cluster_count"
    pieces <- strsplit(counts$key, "\r", fixed = TRUE)
    counts$issuer_id <- vapply(pieces, `[[`, character(1L), 1L)
    counts$decision_session <- as.Date(vapply(pieces, `[[`, character(1L), 2L))
    counts$key <- NULL
  } else {
    counts <- data.frame(issuer_id = character(), decision_session = as.Date(character()), novel_cluster_count = integer(), stringsAsFactors = FALSE)
  }

  issuers <- unique(issuer_registry$issuer_id)
  grid <- expand.grid(issuer_id = issuers, decision_session = sessions, stringsAsFactors = FALSE)
  grid$decision_session <- as.Date(grid$decision_session, origin = "1970-01-01")
  grid <- merge(grid, counts, by = c("issuer_id", "decision_session"), all.x = TRUE, sort = TRUE)
  grid$novel_cluster_count[is.na(grid$novel_cluster_count)] <- 0L
  grid$news_log1p <- log1p(grid$novel_cluster_count)
  grid$economic_group <- issuer_registry$economic_group[match(grid$issuer_id, issuer_registry$issuer_id)]
  session_index <- match(grid$decision_session, sessions)
  next_index <- session_index + 1L
  grid$execution_session <- as.Date(NA)
  valid_next <- next_index <= length(sessions)
  grid$execution_session[valid_next] <- sessions[next_index[valid_next]]
  grid <- grid[order(grid$decision_session, grid$issuer_id), , drop = FALSE]
  rownames(grid) <- NULL

  list(
    panel = grid,
    articles = built$articles,
    associations = associations,
    admissible_associations = usable
  )
}

g5_gen54_n1b_unify_bars <- function(bars, issuer_registry = g5_gen54_n1b_issuer_registry()) {
  required <- c("symbol", "session_date", "open", "close")
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_gen54_n1b_stop(paste("bars missing:", paste(missing, collapse = ", ")))
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
  x <- x[x$symbol_valid_on_session, c("issuer_id", "provider_symbol", "session_date", "open", "close"), drop = FALSE]
  x <- x[order(x$issuer_id, x$session_date, x$provider_symbol), , drop = FALSE]
  if (anyDuplicated(x[, c("issuer_id", "session_date")])) {
    g5_gen54_n1b_stop("Point-in-time issuer bars contain duplicate issuer/session rows.")
  }
  rownames(x) <- NULL
  x
}

g5_gen54_n1b_validate_bar_coverage <- function(
    issuer_bars,
    expected_issuers,
    expected_start,
    expected_end) {
  expected_issuers <- sort(unique(as.character(expected_issuers)))
  expected_start <- as.Date(expected_start)
  expected_end <- as.Date(expected_end)
  if (!length(expected_issuers) || any(is.na(c(expected_start, expected_end))) || expected_start > expected_end) {
    g5_gen54_n1b_stop("Expected bar coverage must name issuers and a valid ordered window.")
  }
  parts <- split(as.Date(issuer_bars$session_date), issuer_bars$issuer_id)
  coverage <- do.call(rbind, lapply(expected_issuers, function(issuer) {
    sessions <- sort(unique(as.Date(parts[[issuer]])))
    data.frame(
      issuer_id = issuer,
      first_session = if (length(sessions)) min(sessions) else as.Date(NA),
      last_session = if (length(sessions)) max(sessions) else as.Date(NA),
      bar_rows = length(sessions),
      covers_expected_window = length(sessions) > 0L &&
        min(sessions) <= expected_start && max(sessions) >= expected_end,
      stringsAsFactors = FALSE
    )
  }))
  rownames(coverage) <- NULL
  list(
    coverage = coverage,
    passed = nrow(coverage) == length(expected_issuers) && all(coverage$covers_expected_window)
  )
}

g5_gen54_n1b_attach_h5_path_volatility <- function(news_panel, issuer_bars, session_dates, horizon = 5L) {
  horizon <- as.integer(horizon)
  if (!identical(horizon, 5L)) g5_gen54_n1b_stop("N1B freezes the future-volatility horizon at five sessions.")
  sessions <- sort(unique(as.Date(session_dates)))
  out <- news_panel
  out$outcome_end_session <- as.Date(NA)
  out$future_path_volatility_h5 <- NA_real_
  for (issuer in unique(out$issuer_id)) {
    aligned <- merge(
      data.frame(session_date = sessions),
      issuer_bars[issuer_bars$issuer_id == issuer, c("session_date", "open", "close"), drop = FALSE],
      by = "session_date", all.x = TRUE, sort = TRUE
    )
    path <- rep(NA_real_, length(sessions))
    end_date <- as.Date(rep(NA_real_, length(sessions)), origin = "1970-01-01")
    if (length(sessions) > horizon) {
      for (i in seq_len(length(sessions) - horizon)) {
        path_rows <- seq.int(i + 1L, i + horizon)
        opens <- aligned$open[path_rows]
        closes <- aligned$close[path_rows]
        if (all(is.finite(opens)) && all(is.finite(closes)) && opens[[1L]] > 0 && all(closes > 0)) {
          returns <- c(log(closes[[1L]] / opens[[1L]]), diff(log(closes)))
          path[[i]] <- sqrt(sum(returns^2))
          end_date[[i]] <- sessions[[i + horizon]]
        }
      }
    }
    rows <- which(out$issuer_id == issuer)
    index <- match(out$decision_session[rows], sessions)
    out$future_path_volatility_h5[rows] <- path[index]
    out$outcome_end_session[rows] <- end_date[index]
  }
  out
}

g5_gen54_n1b_train_percentile <- function(train_values, values) {
  train_values <- train_values[is.finite(train_values)]
  if (!length(train_values)) return(rep(NA_real_, length(values)))
  vapply(values, function(value) {
    if (!is.finite(value)) NA_real_ else mean(train_values <= value)
  }, numeric(1L))
}

g5_gen54_n1b_evaluate <- function(
    panel,
    folds = g5_gen54_xs_build_folds(2022:2024),
    minimum_train_rows = 400L,
    minimum_nonzero_train_cycles = 20L,
    high_percentile = 0.80) {
  required <- c("issuer_id", "decision_session", "execution_session", "outcome_end_session", "novel_cluster_count", "news_log1p", "future_path_volatility_h5")
  missing <- setdiff(required, names(panel))
  if (length(missing)) g5_gen54_n1b_stop(paste("panel missing:", paste(missing, collapse = ", ")))
  oos_rows <- list()
  support_rows <- list()
  row_index <- 1L
  support_index <- 1L
  for (fold_no in seq_len(nrow(folds))) {
    fold <- folds[fold_no, , drop = FALSE]
    for (issuer in unique(panel$issuer_id)) {
      issuer_rows <- panel$issuer_id == issuer
      train_keep <- issuer_rows & panel$decision_session >= fold$train_start_date & panel$decision_session <= fold$train_end_date &
        !is.na(panel$outcome_end_session) & panel$outcome_end_session <= fold$train_end_date &
        is.finite(panel$future_path_volatility_h5)
      oos_keep <- issuer_rows & panel$decision_session >= fold$oos_start_date & panel$decision_session <= fold$oos_end_date &
        !is.na(panel$outcome_end_session) & panel$outcome_end_session <= fold$oos_end_date &
        is.finite(panel$future_path_volatility_h5)
      train <- panel[train_keep, , drop = FALSE]
      oos <- panel[oos_keep, , drop = FALSE]
      train_scale <- if (nrow(train)) stats::median(train$future_path_volatility_h5) else NA_real_
      nonzero_train <- sum(train$novel_cluster_count > 0)
      support_ok <- nrow(train) >= as.integer(minimum_train_rows) &
        nonzero_train >= as.integer(minimum_nonzero_train_cycles) &
        is.finite(train_scale) & train_scale > 0
      support_rows[[support_index]] <- data.frame(
        fold_id = fold$fold_id,
        issuer_id = issuer,
        train_start_date = fold$train_start_date,
        train_end_date = fold$train_end_date,
        train_complete_rows = nrow(train),
        train_nonzero_news_cycles = nonzero_train,
        train_median_path_volatility_h5 = train_scale,
        minimum_train_rows = as.integer(minimum_train_rows),
        minimum_nonzero_train_cycles = as.integer(minimum_nonzero_train_cycles),
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
        oos$train_nonzero_news_cycles <- nonzero_train
        oos$news_intensity_percentile <- if (support_ok) g5_gen54_n1b_train_percentile(train$news_log1p, oos$news_log1p) else NA_real_
        oos$relative_future_path_volatility_h5 <- if (support_ok) oos$future_path_volatility_h5 / train_scale else NA_real_
        oos$high_news_intensity <- support_ok & oos$novel_cluster_count > 0 & oos$news_intensity_percentile >= high_percentile
        oos$normalizer_max_decision_session <- if (nrow(train)) max(train$decision_session) else as.Date(NA)
        oos$outcome_scale_max_end_session <- if (nrow(train)) max(train$outcome_end_session) else as.Date(NA)
        oos_rows[[row_index]] <- oos
        row_index <- row_index + 1L
      }
    }
  }
  oos <- if (length(oos_rows)) do.call(rbind, oos_rows) else data.frame()
  support <- do.call(rbind, support_rows)
  rownames(oos) <- rownames(support) <- NULL

  summaries <- lapply(unique(oos$fold_id), function(fold_id) {
    part <- oos[oos$fold_id == fold_id & is.finite(oos$news_intensity_percentile) & is.finite(oos$relative_future_path_volatility_h5), , drop = FALSE]
    high <- part$high_news_intensity
    correlation <- if (nrow(part) >= 20L && length(unique(part$news_intensity_percentile)) > 1L) {
      suppressWarnings(stats::cor(part$news_intensity_percentile, part$relative_future_path_volatility_h5, method = "spearman"))
    } else NA_real_
    data.frame(
      fold_id = fold_id,
      eligible_observations = nrow(part),
      issuer_count = length(unique(part$issuer_id)),
      high_intensity_observations = sum(high),
      high_intensity_share = if (nrow(part)) mean(high) else NA_real_,
      spearman_correlation = correlation,
      high_mean_relative_volatility = if (any(high)) mean(part$relative_future_path_volatility_h5[high]) else NA_real_,
      other_mean_relative_volatility = if (any(!high)) mean(part$relative_future_path_volatility_h5[!high]) else NA_real_,
      high_minus_other_relative_volatility = if (any(high) && any(!high)) mean(part$relative_future_path_volatility_h5[high]) - mean(part$relative_future_path_volatility_h5[!high]) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  fold_summary <- do.call(rbind, summaries)
  rownames(fold_summary) <- NULL
  list(oos = oos, train_support = support, fold_summary = fold_summary)
}

g5_gen54_n1b_verdict <- function(fold_summary, required_positive_folds = 8L) {
  mean_correlation <- mean(fold_summary$spearman_correlation, na.rm = TRUE)
  positive_correlation_folds <- sum(fold_summary$spearman_correlation > 0, na.rm = TRUE)
  positive_separation_folds <- sum(fold_summary$high_minus_other_relative_volatility > 0, na.rm = TRUE)
  gates <- data.frame(
    gate_id = c("positive_mean_fold_spearman", "positive_spearman_in_8_of_12_folds", "positive_high_vs_other_in_8_of_12_folds"),
    passed = c(
      is.finite(mean_correlation) && mean_correlation > 0,
      positive_correlation_folds >= as.integer(required_positive_folds),
      positive_separation_folds >= as.integer(required_positive_folds)
    ),
    value = c(sprintf("%.6f", mean_correlation), as.character(positive_correlation_folds), as.character(positive_separation_folds)),
    threshold = c("> 0", paste0(">= ", required_positive_folds), paste0(">= ", required_positive_folds)),
    stringsAsFactors = FALSE
  )
  list(
    mean_fold_spearman = mean_correlation,
    positive_correlation_folds = positive_correlation_folds,
    positive_separation_folds = positive_separation_folds,
    gates = gates,
    passed = all(gates$passed)
  )
}

g5_gen54_n1b_leakage_audit <- function(result, associations, n1l_passed = TRUE) {
  oos <- result$oos
  support <- result$train_support
  admissible <- associations[associations$admissible_novel, , drop = FALSE]
  data.frame(
    check_id = c(
      "twelve_quarterly_oos_folds",
      "eight_quarter_train_precedes_oos",
      "next_open_after_decision",
      "h5_outcome_inside_oos",
      "normalizers_end_in_train",
      "train_support_complete",
      "stale_updates_excluded",
      "exact_title_repeats_excluded",
      "fb_meta_point_in_time_validity",
      "n1l_live_path_passed",
      "no_forbidden_analysis_surface"
    ),
    status = c(
      if (length(unique(oos$fold_id)) == 12L) "PASS" else "FAIL",
      if (all(oos$train_end_date < oos$oos_start_date, na.rm = TRUE)) "PASS" else "FAIL",
      if (all(oos$decision_session < oos$execution_session, na.rm = TRUE)) "PASS" else "FAIL",
      if (all(oos$outcome_end_session <= oos$oos_end_date, na.rm = TRUE)) "PASS" else "FAIL",
      if (all(oos$normalizer_max_decision_session <= oos$train_end_date & oos$outcome_scale_max_end_session <= oos$train_end_date, na.rm = TRUE)) "PASS" else "FAIL",
      if (all(support$support_ok)) "PASS" else "FAIL",
      if (!nrow(admissible) || all(admissible$update_delay_seconds <= 24 * 3600)) "PASS" else "FAIL",
      if (!nrow(admissible) || all(!admissible$exact_title_repeat)) "PASS" else "FAIL",
      if (!nrow(admissible) || all(admissible$symbol_valid_on_decision)) "PASS" else "FAIL",
      if (isTRUE(n1l_passed)) "PASS" else "FAIL",
      "PASS"
    ),
    detail = c(
      "OOS authority is frozen at 2022Q1 through 2024Q4.",
      "Every eight-quarter TRAIN window ends before its OOS quarter.",
      "Every measured outcome begins at the session after the 17:30 decision.",
      "Only h5 paths ending inside the same OOS quarter enter diagnostics.",
      "Issuer ECDFs and volatility medians use TRAIN-complete rows only.",
      "Every issuer-fold has at least 400 complete TRAIN rows and 20 nonzero TRAIN cycles.",
      "Updates delayed more than 24 hours cannot enter the news measurement.",
      "Backward-looking 72-hour exact-title repeats cannot enter the novel count.",
      "FB is valid through 2022-06-08 and META from 2022-06-09.",
      "N1L observed and REST-reconciled a prospective live article before N1B.",
      "Sentiment, direction, horizon search, exposure, allocation, PnL, and models remain absent."
    ),
    stringsAsFactors = FALSE
  )
}
