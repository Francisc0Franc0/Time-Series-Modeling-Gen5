g5_gen54_e0_stop <- function(message) {
  if (exists("g5_stop", mode = "function")) g5_stop(message) else stop(message, call. = FALSE)
}

g5_gen54_e0_quarter_id <- function(x) {
  date <- as.Date(x)
  paste0(
    format(date, "%Y"),
    "Q",
    (as.integer(format(date, "%m")) - 1L) %/% 3L + 1L
  )
}

g5_gen54_e0_cutoff_timestamp <- function(
    decision_session,
    cutoff_time = "17:30:00",
    timezone = "America/New_York") {
  if (!grepl("^[0-2][0-9]:[0-5][0-9]:[0-5][0-9]$", cutoff_time)) {
    g5_gen54_e0_stop("cutoff_time must use HH:MM:SS.")
  }
  out <- as.POSIXct(
    paste(as.Date(decision_session), cutoff_time),
    format = "%Y-%m-%d %H:%M:%S",
    tz = timezone
  )
  attr(out, "tzone") <- "UTC"
  out
}

g5_gen54_e0_enrich_admissible_associations <- function(news) {
  required_news <- c("articles", "admissible_associations")
  if (!is.list(news) || !all(required_news %in% names(news))) {
    g5_gen54_e0_stop("news must contain articles and admissible_associations.")
  }
  articles <- news$articles
  associations <- news$admissible_associations
  required_articles <- c(
    "article_id", "headline", "source", "symbols", "created_at", "updated_at",
    "update_delay_seconds", "revision_crossed_decision_cycle"
  )
  required_associations <- c(
    "article_id", "issuer_id", "symbol", "decision_session",
    "execution_session", "exact_title_cluster_id", "admissible_novel"
  )
  missing_articles <- setdiff(required_articles, names(articles))
  missing_associations <- setdiff(required_associations, names(associations))
  if (length(missing_articles)) {
    g5_gen54_e0_stop(paste("news articles missing:", paste(missing_articles, collapse = ", ")))
  }
  if (length(missing_associations)) {
    g5_gen54_e0_stop(paste("news associations missing:", paste(missing_associations, collapse = ", ")))
  }
  if (!nrow(associations)) g5_gen54_e0_stop("No admissible novel associations were supplied.")

  article_row <- match(associations$article_id, articles$article_id)
  if (any(is.na(article_row))) {
    g5_gen54_e0_stop("At least one admissible association lacks article authority.")
  }
  out <- associations
  issuer_registry <- g5_gen54_n1b_issuer_registry()
  out$economic_group <- issuer_registry$economic_group[
    match(out$issuer_id, issuer_registry$issuer_id)
  ]
  if (any(is.na(out$economic_group))) {
    g5_gen54_e0_stop("At least one admissible association lacks an economic group.")
  }
  for (column in required_articles[required_articles != "article_id"]) {
    out[[column]] <- articles[[column]][article_row]
  }
  out$availability_timestamp <- g5_gen54_news_parse_timestamp(
    out$updated_at,
    "updated_at"
  )
  out$decision_cutoff_timestamp <- g5_gen54_e0_cutoff_timestamp(out$decision_session)
  out$age_hours_at_decision <- as.numeric(difftime(
    out$decision_cutoff_timestamp,
    out$availability_timestamp,
    units = "hours"
  ))
  symbol_lists <- strsplit(as.character(out$symbols), "|", fixed = TRUE)
  out$provider_symbol_count <- lengths(lapply(symbol_lists, unique))
  out$multi_symbol_article <- out$provider_symbol_count > 1L
  out$information_cycle_id <- paste0(
    "cycle_", out$issuer_id, "_", format(out$decision_session, "%Y%m%d")
  )
  out <- out[order(
    out$decision_session,
    out$issuer_id,
    out$availability_timestamp,
    out$article_id
  ), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_gen54_e0_build_cycles <- function(events) {
  required <- c(
    "information_cycle_id", "issuer_id", "economic_group", "decision_session",
    "execution_session", "article_id", "exact_title_cluster_id", "source",
    "headline", "availability_timestamp", "decision_cutoff_timestamp",
    "age_hours_at_decision", "update_delay_seconds",
    "revision_crossed_decision_cycle", "multi_symbol_article"
  )
  missing <- setdiff(required, names(events))
  if (length(missing)) {
    g5_gen54_e0_stop(paste("events missing:", paste(missing, collapse = ", ")))
  }
  pieces <- split(seq_len(nrow(events)), events$information_cycle_id)
  cycles <- do.call(rbind, lapply(pieces, function(index) {
    part <- events[index, , drop = FALSE]
    sources <- sort(unique(trimws(as.character(part$source))))
    sources <- sources[nzchar(sources)]
    headlines <- unique(trimws(as.character(part$headline)))
    headlines <- headlines[nzchar(headlines)]
    data.frame(
      information_cycle_id = part$information_cycle_id[[1L]],
      issuer_id = part$issuer_id[[1L]],
      economic_group = part$economic_group[[1L]],
      decision_session = part$decision_session[[1L]],
      execution_session = part$execution_session[[1L]],
      decision_cutoff_timestamp = part$decision_cutoff_timestamp[[1L]],
      novel_cluster_count = length(unique(part$exact_title_cluster_id)),
      article_count = length(unique(part$article_id)),
      source_count = length(sources),
      source_sample = paste(head(sources, 4L), collapse = " | "),
      first_availability_timestamp = min(part$availability_timestamp),
      last_availability_timestamp = max(part$availability_timestamp),
      youngest_age_hours = min(part$age_hours_at_decision),
      oldest_age_hours = max(part$age_hours_at_decision),
      revision_crossed_cycle_count = sum(part$revision_crossed_decision_cycle),
      multi_symbol_article_count = sum(part$multi_symbol_article),
      headline_sample = paste(head(headlines, 3L), collapse = " || "),
      stringsAsFactors = FALSE
    )
  }))
  cycles$quarter <- g5_gen54_e0_quarter_id(cycles$decision_session)
  cycles <- cycles[order(cycles$decision_session, cycles$issuer_id), , drop = FALSE]
  rownames(cycles) <- NULL
  cycles
}

g5_gen54_e0_coverage <- function(
    cycles,
    issuer_ids,
    quarters = c("2025Q1", "2025Q2", "2025Q3", "2025Q4", "2026Q1", "2026Q2")) {
  grid <- expand.grid(
    issuer_id = sort(unique(as.character(issuer_ids))),
    quarter = quarters,
    stringsAsFactors = FALSE
  )
  if (nrow(cycles)) {
    counts <- aggregate(
      cycles$information_cycle_id,
      list(issuer_id = cycles$issuer_id, quarter = cycles$quarter),
      length
    )
    names(counts)[[3L]] <- "information_cycle_count"
    clusters <- aggregate(
      cycles$novel_cluster_count,
      list(issuer_id = cycles$issuer_id, quarter = cycles$quarter),
      sum
    )
    names(clusters)[[3L]] <- "novel_cluster_count"
    maximum <- aggregate(
      cycles$novel_cluster_count,
      list(issuer_id = cycles$issuer_id, quarter = cycles$quarter),
      max
    )
    names(maximum)[[3L]] <- "maximum_cycle_cluster_count"
    median_count <- aggregate(
      cycles$novel_cluster_count,
      list(issuer_id = cycles$issuer_id, quarter = cycles$quarter),
      stats::median
    )
    names(median_count)[[3L]] <- "median_cycle_cluster_count"
    out <- Reduce(
      function(x, y) merge(x, y, by = c("issuer_id", "quarter"), all.x = TRUE),
      list(grid, counts, clusters, maximum, median_count)
    )
  } else {
    out <- grid
    out$information_cycle_count <- 0L
    out$novel_cluster_count <- 0L
    out$maximum_cycle_cluster_count <- 0L
    out$median_cycle_cluster_count <- 0
  }
  numeric_columns <- c(
    "information_cycle_count", "novel_cluster_count",
    "maximum_cycle_cluster_count", "median_cycle_cluster_count"
  )
  for (column in numeric_columns) out[[column]][is.na(out[[column]])] <- 0
  out[order(out$quarter, out$issuer_id), , drop = FALSE]
}

g5_gen54_e0_source_summary <- function(events) {
  source <- trimws(as.character(events$source))
  source[!nzchar(source)] <- "(missing)"
  counts <- aggregate(
    events$article_id,
    list(source = source),
    function(x) length(unique(x))
  )
  names(counts)[[2L]] <- "unique_article_count"
  counts$article_share <- counts$unique_article_count / sum(counts$unique_article_count)
  counts[order(-counts$unique_article_count, counts$source), , drop = FALSE]
}

g5_gen54_e0_representative_tape <- function(events, cycles) {
  quarters <- unique(cycles$quarter)
  chosen <- do.call(rbind, lapply(quarters, function(quarter) {
    part <- cycles[cycles$quarter == quarter, , drop = FALSE]
    part <- part[order(-part$novel_cluster_count, part$decision_session, part$issuer_id), , drop = FALSE]
    part[1L, , drop = FALSE]
  }))
  tape <- do.call(rbind, lapply(seq_len(nrow(chosen)), function(i) {
    cycle <- chosen[i, , drop = FALSE]
    part <- events[
      events$information_cycle_id == cycle$information_cycle_id,
      , drop = FALSE
    ]
    part <- part[order(part$availability_timestamp, part$article_id), , drop = FALSE]
    part$article_rank_in_cycle <- seq_len(nrow(part))
    part$quarter <- cycle$quarter
    part[part$article_rank_in_cycle <= 5L, c(
      "quarter", "information_cycle_id", "issuer_id", "decision_session",
      "execution_session", "article_rank_in_cycle", "article_id", "source",
      "headline", "availability_timestamp", "age_hours_at_decision",
      "provider_symbol_count"
    ), drop = FALSE]
  }))
  rownames(tape) <- NULL
  tape
}

g5_gen54_e0_authority_keys <- function(events) {
  sort(unique(paste(
    events$article_id,
    events$issuer_id,
    events$decision_session,
    events$exact_title_cluster_id,
    sep = "\r"
  )))
}

g5_gen54_e0_integrity_audit <- function(
    events,
    cycles,
    coverage,
    source_leakage_passed,
    authority_reproduced,
    raw_pages_ok,
    minimum_cycles_per_issuer_quarter = 5L) {
  forbidden <- c(
    "return", "outcome", "future", "price", "open", "close", "volume",
    "sentiment", "score", "prediction", "pnl"
  )
  all_names <- tolower(c(names(events), names(cycles), names(coverage)))
  forbidden_present <- vapply(
    forbidden,
    function(token) any(grepl(token, all_names, fixed = TRUE)),
    logical(1L)
  )
  data.frame(
    check_id = c(
      "accepted_source_integrity",
      "raw_page_chain_complete",
      "rebuild_matches_admitted_associations",
      "availability_no_later_than_decision",
      "execution_after_decision",
      "stale_updates_absent",
      "exact_title_repeats_absent",
      "issuer_cycle_ids_unique",
      "positive_cluster_count_per_cycle",
      "all_24_issuers_cover_all_6_quarters",
      "minimum_5_cycles_per_issuer_quarter",
      "no_price_outcome_or_model_surface"
    ),
    status = c(
      if (isTRUE(source_leakage_passed)) "PASS" else "FAIL",
      if (isTRUE(raw_pages_ok)) "PASS" else "FAIL",
      if (isTRUE(authority_reproduced)) "PASS" else "FAIL",
      if (all(events$availability_timestamp <= events$decision_cutoff_timestamp)) "PASS" else "FAIL",
      if (all(events$decision_session < events$execution_session)) "PASS" else "FAIL",
      if (all(events$update_delay_seconds <= 24 * 3600)) "PASS" else "FAIL",
      if (all(!events$exact_title_repeat)) "PASS" else "FAIL",
      if (!anyDuplicated(cycles$information_cycle_id)) "PASS" else "FAIL",
      if (all(cycles$novel_cluster_count >= 1L)) "PASS" else "FAIL",
      if (length(unique(events$issuer_id)) == 24L &&
          length(unique(cycles$quarter)) == 6L &&
          all(coverage$information_cycle_count > 0L)) "PASS" else "FAIL",
      if (all(coverage$information_cycle_count >= as.integer(minimum_cycles_per_issuer_quarter))) "PASS" else "FAIL",
      if (!any(forbidden_present)) "PASS" else "FAIL"
    ),
    detail = c(
      "The accepted N1D input packet must retain all of its frozen integrity checks.",
      "Every preserved Alpaca page must be HTTP 200 and each partition must terminate without another token.",
      "The raw-page rebuild must reproduce every admitted article/issuer/session/cluster association.",
      "Historical availability uses updated_at and cannot fall after the 17:30 America/New_York decision cutoff.",
      "The information cycle is observed at decision close and maps only to the following market session.",
      "Updates delayed more than 24 hours cannot enter an information cycle.",
      "Backward-only exact-title repeats within 72 hours cannot enter a novel cycle.",
      "There is exactly one issuer information cycle per issuer and scheduled decision.",
      "Every retained information cycle contains at least one admissible novel cluster.",
      "Every issuer has at least one cycle in every 2025Q1-2026Q2 quarter.",
      "Each issuer-quarter must contain at least five observable information cycles.",
      "E0 contains no price response, outcome, sentiment, predictive score, model, policy, PnL, or live authority."
    ),
    stringsAsFactors = FALSE
  )
}
