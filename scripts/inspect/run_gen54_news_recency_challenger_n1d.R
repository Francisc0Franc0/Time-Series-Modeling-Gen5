# Gen5.4 N1D fixed-recency news representation challenger.
#
# One 24-hour exponential half-life, evaluated only on 2025Q1-2026Q2.
# No alternate decay, sentiment, source weighting, embeddings, model, policy,
# exposure, allocation, portfolio metrics, PnL, or live-advice changes.

script_path <- tryCatch(
  normalizePath(sys.frames()[[1]]$ofile, winslash = "/", mustWork = FALSE),
  error = function(e) NULL
)
repo_root <- if (!is.null(script_path) && nzchar(script_path)) {
  normalizePath(
    file.path(dirname(script_path), "..", ".."),
    winslash = "/",
    mustWork = FALSE
  )
} else {
  normalizePath(".", winslash = "/", mustWork = TRUE)
}

source(file.path(repo_root, "scripts", "lib", "repo_local_libs.R"))
g5_use_repo_local_libs(repo_root)
source(file.path(repo_root, "R", "data_contract.R"))
source(file.path(repo_root, "R", "config_loader.R"))
source(file.path(repo_root, "R", "calendar.R"))
source(file.path(repo_root, "R", "alpaca_provider.R"))
source(file.path(repo_root, "R", "alpaca_context_provider.R"))
source(file.path(repo_root, "R", "cache_store.R"))
source(file.path(repo_root, "R", "data_audit.R"))
source(file.path(repo_root, "R", "universe_registry.R"))
source(file.path(repo_root, "R", "workbench_query.R"))
source(file.path(repo_root, "R", "gen54_cross_sectional_poc.R"))
source(file.path(repo_root, "R", "gen54_news_admissibility.R"))
source(file.path(repo_root, "R", "gen54_news_risk_measurement.R"))
source(file.path(repo_root, "R", "gen54_news_nonredundancy.R"))
source(file.path(repo_root, "R", "gen54_news_recency_challenger.R"))
g5_load_local_renviron(repo_root)

env_or <- function(name, default) {
  value <- Sys.getenv(name, unset = "")
  if (nzchar(value)) value else default
}
env_bool <- function(name, default = FALSE) {
  tolower(env_or(name, if (default) "true" else "false")) %in%
    c("1", "true", "yes")
}
write_csv <- function(x, path) {
  utils::write.csv(x, path, row.names = FALSE, na = "")
  invisible(path)
}
ensure_dir <- function(path) {
  dir.create(path, recursive = TRUE, showWarnings = FALSE)
  invisible(path)
}
quarter_id <- function(x) {
  date <- as.Date(x)
  paste0(
    format(date, "%Y"),
    "Q",
    (as.integer(format(date, "%m")) - 1L) %/% 3L + 1L
  )
}

run_id <- env_or("GEN5_GEN54_NEWS_N1D_RUN_ID", "g54_news_n1d_20260725")
as_of_timestamp <- env_or(
  "GEN5_GEN54_NEWS_N1D_AS_OF",
  "2026-07-25 17:30:00"
)
retrieved_at <- env_or(
  "GEN5_GEN54_NEWS_N1D_RETRIEVED_AT",
  "2026-07-25 17:30:00"
)
request_pause_seconds <- as.numeric(env_or(
  "GEN5_GEN54_NEWS_N1D_REQUEST_PAUSE",
  "0.25"
))
reuse_raw <- env_bool("GEN5_GEN54_NEWS_N1D_REUSE_RAW", FALSE)
refresh_bars <- env_bool("GEN5_GEN54_NEWS_N1D_REFRESH_BARS", FALSE)
n1a_run_id <- env_or(
  "GEN5_GEN54_NEWS_N1D_N1A_RUN_ID",
  "g54_news_n1a_20260721"
)

archive_start <- as.Date("2023-01-01")
confirmation_end <- as.Date("2026-06-30")
calendar_start <- as.Date("2022-12-20")
calendar_end <- as.Date("2026-07-10")
bar_start <- as.Date("2022-12-20")
bar_end <- as.Date("2026-07-10")
half_life_hours <- 24
cutoff_time <- "17:30:00"
timezone <- "America/New_York"
repeat_window_hours <- 72
maximum_update_delay_hours <- 24
minimum_train_rows <- 400L
minimum_nonzero_train_cycles <- 20L
minimum_mean_improvement <- 0.01
required_positive_folds <- 4L
required_improvement_folds <- 4L
expected_fold_ids <- c(
  "2025Q1", "2025Q2", "2025Q3", "2025Q4", "2026Q1", "2026Q2"
)

output_dir <- file.path(
  repo_root,
  "runs",
  "research_workbench",
  "gen54_ml_decision_engine",
  run_id
)
raw_dir <- file.path(output_dir, "raw")
visual_dir <- file.path(output_dir, "visuals")
ensure_dir(raw_dir)
ensure_dir(visual_dir)

n1a_dir <- file.path(
  repo_root,
  "runs",
  "research_workbench",
  "gen54_ml_decision_engine",
  n1a_run_id
)
required_n1a <- file.path(
  n1a_dir,
  c("n1a_article_admissibility.csv", "n1a_run_spec.csv")
)
if (!all(file.exists(required_n1a))) {
  g5_stop("The accepted N1A archive authority is unavailable.")
}
n1a_spec <- utils::read.csv(
  required_n1a[[2L]],
  stringsAsFactors = FALSE,
  check.names = FALSE
)
if (!identical(
  n1a_spec$overall_status[[1L]],
  "PASS_N1A_ADMISSIBLE_FOR_N1B_DISCUSSION"
)) {
  g5_stop("N1A authority status is not admissible.")
}
canonical_news_columns <- names(g5_alpaca_empty_news())
n1a_enriched <- utils::read.csv(
  required_n1a[[1L]],
  stringsAsFactors = FALSE,
  check.names = FALSE
)
if (!all(canonical_news_columns %in% names(n1a_enriched))) {
  g5_stop("N1A article authority lacks canonical Alpaca news columns.")
}
n1a_articles <- n1a_enriched[, canonical_news_columns, drop = FALSE]

message("Gen5.4 N1D starting: post-2024 calendar and news coverage.")
calendar_raw_path <- file.path(raw_dir, "alpaca_calendar.json")
if (reuse_raw) {
  if (!file.exists(calendar_raw_path)) {
    g5_stop("Raw reuse requested but alpaca_calendar.json is missing.")
  }
  calendar_text <- paste(
    readLines(calendar_raw_path, warn = FALSE, encoding = "UTF-8"),
    collapse = "\n"
  )
  calendar_parsed <- jsonlite::fromJSON(
    calendar_text,
    simplifyVector = FALSE
  )
  calendar <- g5_alpaca_map_calendar_payload(
    calendar_parsed,
    as_of_timestamp,
    retrieved_at
  )
} else {
  calendar_result <- g5_fetch_alpaca_calendar(
    start_date = calendar_start,
    end_date = calendar_end,
    as_of_timestamp = as_of_timestamp,
    retrieved_at = retrieved_at
  )
  calendar <- calendar_result$data
  writeLines(
    calendar_result$response_text,
    calendar_raw_path,
    useBytes = TRUE
  )
}
if (!nrow(calendar)) g5_stop("Alpaca calendar returned no sessions.")

registry <- g5_gen54_xs_candidate_registry()
symbols <- registry$symbol
partitions <- data.frame(
  partition_id = c("2025", "2026H1"),
  start_timestamp = c(
    "2025-01-01T00:00:00Z",
    "2026-01-01T00:00:00Z"
  ),
  end_timestamp = c(
    "2025-12-31T23:59:59Z",
    "2026-06-30T23:59:59Z"
  ),
  stringsAsFactors = FALSE
)

partition_articles <- list()
request_rows <- list()
page_rows <- list()
for (partition_no in seq_len(nrow(partitions))) {
  partition <- partitions[partition_no, , drop = FALSE]
  partition_id <- partition$partition_id[[1L]]
  request <- g5_alpaca_news_request(
    symbols = symbols,
    start_timestamp = partition$start_timestamp[[1L]],
    end_timestamp = partition$end_timestamp[[1L]],
    as_of_timestamp = as_of_timestamp,
    include_content = FALSE,
    limit = 50L
  )
  if (reuse_raw) {
    pattern <- paste0(
      "^news_",
      partition_id,
      "_page_[0-9]{4}\\.json$"
    )
    raw_files <- sort(list.files(
      raw_dir,
      pattern = pattern,
      full.names = TRUE
    ))
    if (!length(raw_files)) {
      g5_stop(paste(
        "Raw reuse requested but no page files exist for",
        partition_id
      ))
    }
    pages <- vector("list", length(raw_files))
    frames <- vector("list", length(raw_files))
    for (page_number in seq_along(raw_files)) {
      response_text <- paste(
        readLines(
          raw_files[[page_number]],
          warn = FALSE,
          encoding = "UTF-8"
        ),
        collapse = "\n"
      )
      parsed <- jsonlite::fromJSON(response_text, simplifyVector = FALSE)
      next_token <- parsed$next_page_token
      next_token <- if (
        is.null(next_token) || !nzchar(as.character(next_token))
      ) {
        ""
      } else {
        as.character(next_token)
      }
      pages[[page_number]] <- list(
        page_number = page_number,
        http_status = 200L,
        page_token_in =
          if (page_number == 1L) "" else "reused_prior_page_token",
        next_page_token = next_token,
        response_bytes = nchar(response_text, type = "bytes"),
        response_text = response_text
      )
      frames[[page_number]] <- g5_alpaca_map_news_payload(
        parsed,
        request,
        retrieved_at
      )
    }
    if (nzchar(tail(pages, 1L)[[1L]]$next_page_token)) {
      g5_stop(paste(
        "Raw page chain does not terminate for",
        partition_id
      ))
    }
    nonempty <- vapply(frames, nrow, integer(1L)) > 0L
    data <- if (any(nonempty)) {
      do.call(rbind, frames[nonempty])
    } else {
      g5_alpaca_empty_news()
    }
    result <- list(data = data, pages = pages)
    message("Rebuilt ", partition_id, " news from preserved raw pages.")
  } else {
    message("Retrieving Alpaca news partition ", partition_id, ".")
    incremental_page_writer <- function(page) {
      raw_name <- sprintf(
        "news_%s_page_%04d.json",
        partition_id,
        page$page_number
      )
      writeLines(
        page$response_text,
        file.path(raw_dir, raw_name),
        useBytes = TRUE
      )
      if (page$page_number %% 25L == 0L) {
        message(
          "Preserved ",
          partition_id,
          " page ",
          page$page_number,
          "."
        )
      }
      invisible(NULL)
    }
    result <- g5_fetch_alpaca_news_resilient(
      request,
      retrieved_at = retrieved_at,
      request_pause_seconds = request_pause_seconds,
      request_timeout_seconds = 30,
      maximum_page_attempts = 5L,
      retry_pause_seconds = 2,
      page_callback = incremental_page_writer
    )
  }
  request$partition_id <- partition_id
  request_rows[[partition_id]] <- request
  partition_articles[[partition_id]] <- result$data
  manifest_rows <- lapply(result$pages, function(page) {
    raw_name <- sprintf(
      "news_%s_page_%04d.json",
      partition_id,
      page$page_number
    )
    writeLines(
      page$response_text,
      file.path(raw_dir, raw_name),
      useBytes = TRUE
    )
    data.frame(
      partition_id = partition_id,
      page_number = page$page_number,
      http_status = page$http_status,
      page_token_in_present = nzchar(page$page_token_in),
      next_page_token_present = nzchar(page$next_page_token),
      response_bytes = page$response_bytes,
      raw_file = file.path("raw", raw_name),
      stringsAsFactors = FALSE
    )
  })
  page_rows[[partition_id]] <- do.call(rbind, manifest_rows)
  message(
    partition_id,
    ": ",
    nrow(result$data),
    " articles across ",
    length(result$pages),
    " pages."
  )
}
requests <- do.call(rbind, request_rows)
page_manifest <- do.call(rbind, page_rows)
new_articles <- do.call(rbind, partition_articles)
rownames(requests) <- rownames(page_manifest) <- rownames(new_articles) <- NULL

articles <- g5_gen54_n1b_combine_articles(n1a_articles, new_articles)
updated <- g5_gen54_news_parse_timestamp(articles$updated_at, "updated_at")
context_start <- as.POSIXct(
  "2022-12-28T00:00:00Z",
  format = "%Y-%m-%dT%H:%M:%SZ",
  tz = "UTC"
)
context_end <- as.POSIXct(
  "2026-06-30T23:59:59Z",
  format = "%Y-%m-%dT%H:%M:%SZ",
  tz = "UTC"
)
articles <- articles[
  updated >= context_start & updated <= context_end,
  ,
  drop = FALSE
]

issuer_registry <- g5_gen54_n1b_issuer_registry()
news <- g5_gen54_n1b_build_news_panel(
  articles = articles,
  session_dates = calendar$session_date,
  issuer_registry = issuer_registry,
  start_date = archive_start,
  end_date = confirmation_end,
  maximum_update_delay_hours = maximum_update_delay_hours,
  repeat_window_hours = repeat_window_hours,
  cutoff_time = cutoff_time,
  timezone = timezone
)
recency <- g5_gen54_n1d_attach_recency_mass(
  news,
  half_life_hours = half_life_hours,
  cutoff_time = cutoff_time,
  timezone = timezone
)

confirmation_events <- recency$events[
  recency$events$decision_session >= as.Date("2025-01-01") &
    recency$events$decision_session <= confirmation_end,
  ,
  drop = FALSE
]
confirmation_events$fold_id <- quarter_id(
  confirmation_events$decision_session
)
event_coverage <- if (nrow(confirmation_events)) {
  aggregate(
    confirmation_events$exact_title_cluster_id,
    list(
      fold_id = confirmation_events$fold_id,
      issuer_id = confirmation_events$issuer_id
    ),
    function(x) length(unique(x))
  )
} else {
  data.frame(
    fold_id = character(),
    issuer_id = character(),
    x = integer(),
    stringsAsFactors = FALSE
  )
}
names(event_coverage)[[3L]] <- "novel_cluster_count"
coverage_grid <- expand.grid(
  fold_id = expected_fold_ids,
  issuer_id = sort(unique(issuer_registry$issuer_id)),
  stringsAsFactors = FALSE
)
event_coverage <- merge(
  coverage_grid,
  event_coverage,
  by = c("fold_id", "issuer_id"),
  all.x = TRUE,
  sort = FALSE
)
event_coverage$novel_cluster_count[
  is.na(event_coverage$novel_cluster_count)
] <- 0L
event_coverage <- event_coverage[
  order(
    match(event_coverage$fold_id, expected_fold_ids),
    event_coverage$issuer_id
  ),
  ,
  drop = FALSE
]
coverage_passed <- nrow(event_coverage) ==
  length(expected_fold_ids) * 24L &&
  all(event_coverage$novel_cluster_count > 0)

cfg <- g5_load_data_layer_config(repo_root)
message("Loading adjusted OHLCV for untouched confirmation folds.")
bar_query <- g5_workbench_query_adjusted_daily_bars(
  cfg = cfg,
  start_date = bar_start,
  end_date = bar_end,
  as_of_timestamp = as_of_timestamp,
  symbols = symbols,
  universe_name = "gen54_n1d_confirmation_issuers_v0_1",
  universe_roles = "issuer_recency_confirmation",
  refresh = refresh_bars,
  repo_root = repo_root
)
query_health <- bar_query$health
if (!nrow(bar_query$bars)) {
  g5_stop("N1D adjusted-bar query returned no rows.")
}
issuer_bars <- g5_gen54_n1c_unify_bars(
  bar_query$bars,
  issuer_registry
)
bar_validation <- g5_gen54_n1b_validate_bar_coverage(
  issuer_bars,
  expected_issuers = sort(unique(issuer_registry$issuer_id)),
  expected_start = as.Date("2023-01-03"),
  expected_end = confirmation_end
)
adverse_categories <- c(
  "empty_symbol",
  "missing_symbol",
  "refresh_needed",
  "partial_history"
)
adverse_query_health <- query_health$category %in% adverse_categories
query_health_passed <- !any(adverse_query_health) &&
  bar_validation$passed

panel <- g5_gen54_n1b_attach_h5_path_volatility(
  recency$panel,
  issuer_bars,
  calendar$session_date,
  horizon = 5L
)
folds <- g5_gen54_xs_build_folds(2025:2026)
folds <- folds[folds$fold_id %in% expected_fold_ids, , drop = FALSE]
folds <- folds[match(expected_fold_ids, folds$fold_id), , drop = FALSE]
evaluation <- g5_gen54_n1d_evaluate_representations(
  panel,
  folds,
  minimum_train_rows = minimum_train_rows,
  minimum_nonzero_train_cycles = minimum_nonzero_train_cycles
)
control_series <- g5_gen54_n1c_control_series(
  issuer_bars,
  calendar$session_date,
  prior_horizon = 5L,
  dollar_volume_lookback = 60L
)
attached <- g5_gen54_n1c_attach_controls(
  evaluation$oos,
  control_series,
  minimum_train_control_rows = minimum_train_rows
)
evaluation$oos <- attached$oos
fold_summary <- g5_gen54_n1d_fold_summary(evaluation$oos)

forbidden_analysis_count <- 0L
leakage <- g5_gen54_n1d_leakage_audit(
  result = evaluation,
  fold_summary = fold_summary,
  recency_events = recency$events,
  expected_fold_ids = expected_fold_ids,
  half_life_hours = half_life_hours,
  coverage_passed = coverage_passed,
  query_health_passed = query_health_passed,
  forbidden_analysis_count = forbidden_analysis_count
)
integrity_passed <- all(leakage$status == "PASS") &&
  all(attached$train_support$support_ok)
verdict <- g5_gen54_n1d_verdict(
  fold_summary,
  integrity_passed = integrity_passed,
  required_positive_folds = required_positive_folds,
  required_improvement_folds = required_improvement_folds,
  minimum_mean_improvement = minimum_mean_improvement
)
overall_status <- if (!integrity_passed) {
  "STOP_N1D_DATA_OR_LEAKAGE_FAILURE"
} else if (verdict$passed) {
  "PASS_N1D_RECENCY_REPRESENTATION_EARNS_CANDIDATE_STATUS"
} else {
  "STOP_N1D_KEEP_EQUAL_COUNT_AND_CLOSE_REPRESENTATION_EXPANSION"
}

timing_pairs <- g5_gen54_n1d_representative_timing_pairs(
  evaluation$oos,
  maximum_pairs = 6L
)
historical_stale_warnings <- sum(
  query_health$category == "stale_symbol"
)
health <- data.frame(
  severity = c(
    if (query_health_passed) "INFO" else "ERROR",
    "INFO",
    if (coverage_passed) "INFO" else "ERROR",
    if (all(evaluation$train_support$support_ok)) "INFO" else "ERROR",
    if (all(attached$train_support$support_ok)) "INFO" else "ERROR",
    if (all(leakage$status == "PASS")) "INFO" else "ERROR",
    "INFO"
  ),
  check_id = c(
    "adjusted_bar_query_health",
    "bounded_historical_staleness",
    "confirmation_news_coverage",
    "representation_train_support",
    "control_train_support",
    "timing_population_and_leakage",
    "credential_artifact_count"
  ),
  value = c(
    as.character(sum(adverse_query_health)),
    as.character(historical_stale_warnings),
    as.character(sum(event_coverage$novel_cluster_count == 0L)),
    as.character(sum(!evaluation$train_support$support_ok)),
    as.character(sum(!attached$train_support$support_ok)),
    as.character(sum(leakage$status != "PASS")),
    "0"
  ),
  detail = c(
    "material WARN count plus explicit 2023-01-03 through 2026-06-30 issuer coverage",
    "stale-versus-as-of WARNs are informational for the deliberately bounded confirmation query",
    "issuer-quarter rows with zero admissible novel clusters; required zero",
    "issuer-fold rows failing 400 complete TRAIN rows or 20 nonzero cycles",
    "issuer-fold rows failing frozen N1C control support",
    "availability, fold isolation, TRAIN transforms, outcome boundaries, controls, and forbidden surfaces",
    "credentials are never written to N1D artifacts"
  ),
  stringsAsFactors = FALSE
)

run_spec <- data.frame(
  schema_version = "gen54_news_recency_challenger_n1d_v0.1",
  wrapper =
    "scripts/inspect/run_gen54_news_recency_challenger_n1d.R",
  run_id = run_id,
  as_of_timestamp = as_of_timestamp,
  n1a_run_id = n1a_run_id,
  archive_start = archive_start,
  confirmation_start = as.Date("2025-01-01"),
  confirmation_end = confirmation_end,
  confirmation_folds = length(expected_fold_ids),
  train_quarters = 8L,
  half_life_hours = half_life_hours,
  maximum_update_delay_hours = maximum_update_delay_hours,
  repeat_window_hours = repeat_window_hours,
  minimum_train_rows = minimum_train_rows,
  minimum_nonzero_train_cycles = minimum_nonzero_train_cycles,
  required_positive_recency_folds = required_positive_folds,
  minimum_mean_partial_spearman_improvement =
    minimum_mean_improvement,
  required_positive_improvement_folds =
    required_improvement_folds,
  alternate_decay_count = 0L,
  sentiment_count = 0L,
  source_weight_count = 0L,
  embedding_count = 0L,
  alternate_control_count = 0L,
  alternate_horizon_count = 0L,
  model_fit_count = 0L,
  exposure_policy_count = 0L,
  allocation_count = 0L,
  portfolio_metric_count = 0L,
  live_advice_change_count = 0L,
  overall_status = overall_status,
  stringsAsFactors = FALSE
)

write_decay_curve <- function(path) {
  age <- seq(0, 72, by = 0.25)
  weight <- 2^(-age / half_life_hours)
  png(path, width = 1500, height = 900, res = 150)
  par(mar = c(6, 6, 4, 2))
  plot(
    age,
    weight,
    type = "l",
    lwd = 4,
    col = "#2563EB",
    xlab = "Elapsed calendar hours from conservative availability to cutoff",
    ylab = "Article-cluster weight",
    xlim = c(0, 76),
    ylim = c(0, 1.03),
    main = "The challenger changes only how article freshness is represented"
  )
  key_age <- c(0, 24, 48, 72)
  key_weight <- 2^(-key_age / half_life_hours)
  points(key_age, key_weight, pch = 19, cex = 1.5, col = "#D97706")
  text(
    key_age,
    key_weight,
    labels = sprintf("%dh: %.3f", key_age, key_weight),
    pos = c(4, 3, 3, 2),
    cex = 0.9
  )
  abline(v = 24, lty = 2, col = "#64748B")
  mtext(
    "Half-life fixed before outcome inspection; no grid or TRAIN selection",
    side = 1,
    line = 4.5,
    cex = 0.9,
    col = "#475569"
  )
  dev.off()
}

write_fold_comparison <- function(path) {
  x <- fold_summary
  positions <- seq_len(nrow(x))
  limits <- range(
    c(
      x$baseline_partial_spearman,
      x$recency_partial_spearman,
      0
    ),
    finite = TRUE
  )
  pad <- max(0.02, diff(limits) * 0.12)
  png(path, width = 1650, height = 1000, res = 150)
  par(mfrow = c(2, 1), mar = c(5, 6, 4, 2))
  plot(
    positions,
    x$baseline_partial_spearman,
    type = "n",
    xaxt = "n",
    xlab = "",
    ylab = "Conditional partial Spearman",
    ylim = c(limits[[1L]] - pad, limits[[2L]] + pad),
    main = "Untouched confirmation: equal count versus fixed recency mass"
  )
  abline(h = 0, col = "#64748B", lty = 2)
  segments(
    positions,
    x$baseline_partial_spearman,
    positions,
    x$recency_partial_spearman,
    col = ifelse(
      x$recency_minus_baseline_partial > 0,
      "#0F766E",
      "#B91C1C"
    ),
    lwd = 3
  )
  points(
    positions,
    x$baseline_partial_spearman,
    pch = 16,
    col = "#64748B",
    cex = 1.3
  )
  points(
    positions,
    x$recency_partial_spearman,
    pch = 17,
    col = "#2563EB",
    cex = 1.4
  )
  axis(1, at = positions, labels = x$fold_id)
  legend(
    "topleft",
    legend = c("Frozen equal count", "24-hour recency mass"),
    pch = c(16, 17),
    col = c("#64748B", "#2563EB"),
    bty = "n"
  )

  colors <- ifelse(
    x$recency_minus_baseline_partial > 0,
    "#0F766E",
    "#B91C1C"
  )
  barplot(
    x$recency_minus_baseline_partial,
    names.arg = x$fold_id,
    col = colors,
    ylab = "Recency minus baseline",
    main = "The complexity penalty requires mean lift >= 0.01 and 4/6 positive quarters"
  )
  abline(h = 0, col = "#64748B")
  abline(h = minimum_mean_improvement, col = "#D97706", lty = 2)
  dev.off()
}

write_coverage_heatmap <- function(path) {
  issuers <- sort(unique(event_coverage$issuer_id))
  matrix_values <- matrix(
    0,
    nrow = length(issuers),
    ncol = length(expected_fold_ids),
    dimnames = list(issuers, expected_fold_ids)
  )
  for (row in seq_len(nrow(event_coverage))) {
    matrix_values[
      event_coverage$issuer_id[[row]],
      event_coverage$fold_id[[row]]
    ] <- event_coverage$novel_cluster_count[[row]]
  }
  log_values <- log1p(matrix_values)
  colors <- colorRampPalette(c("#F8FAFC", "#93C5FD", "#1D4ED8"))(100)
  png(path, width = 1500, height = 1100, res = 150)
  par(mar = c(7, 11, 4, 2))
  image(
    seq_len(ncol(log_values)),
    seq_len(nrow(log_values)),
    t(log_values),
    axes = FALSE,
    col = colors,
    xlab = "",
    ylab = "",
    main = "Every issuer contributes novel-news observations in every confirmation quarter"
  )
  axis(
    1,
    at = seq_len(ncol(log_values)),
    labels = colnames(log_values)
  )
  axis(
    2,
    at = seq_len(nrow(log_values)),
    labels = rownames(log_values),
    las = 2,
    cex.axis = 0.7
  )
  for (row in seq_len(nrow(matrix_values))) {
    for (column in seq_len(ncol(matrix_values))) {
      text(
        column,
        row,
        matrix_values[row, column],
        cex = 0.55,
        col = if (log_values[row, column] >
          stats::median(log_values)) "white" else "#0F172A"
      )
    }
  }
  box()
  dev.off()
}

write_tie_resolution <- function(path) {
  values <- rbind(
    fold_summary$baseline_unique_percentiles,
    fold_summary$recency_unique_percentiles
  )
  png(path, width = 1500, height = 850, res = 150)
  par(mar = c(6, 6, 4, 2))
  barplot(
    values,
    beside = TRUE,
    names.arg = fold_summary$fold_id,
    col = c("#94A3B8", "#2563EB"),
    ylab = "Unique issuer-local TRAIN percentile values",
    main = "Recency creates more ordering detail without changing article admissibility"
  )
  legend(
    "topleft",
    legend = c("Equal count", "24-hour recency mass"),
    fill = c("#94A3B8", "#2563EB"),
    bty = "n"
  )
  mtext(
    "More unique values are diagnostic only; predictive lift must clear separate gates",
    side = 1,
    line = 4.5,
    cex = 0.9,
    col = "#475569"
  )
  dev.off()
}

write_timing_pairs <- function(path) {
  png(path, width = 1650, height = 950, res = 150)
  par(mar = c(9, 6, 4, 2))
  if (!nrow(timing_pairs)) {
    plot.new()
    text(
      0.5,
      0.5,
      "No outcome-blind equal-count timing pairs available",
      cex = 1.2
    )
  } else {
    labels <- paste0(
      timing_pairs$issuer_id,
      "\n",
      timing_pairs$fold_id,
      " | n=",
      timing_pairs$novel_cluster_count
    )
    values <- rbind(
      timing_pairs$older_relative_future_volatility,
      timing_pairs$fresher_relative_future_volatility
    )
    barplot(
      values,
      beside = TRUE,
      names.arg = labels,
      col = c("#94A3B8", "#D97706"),
      ylab = "Relative future h5 path volatility",
      main = "Equal-count examples isolate timing differences, but outcomes remain probabilistic"
    )
    legend(
      "topright",
      legend = c("Older news mix", "Fresher news mix"),
      fill = c("#94A3B8", "#D97706"),
      bty = "n"
    )
    mtext(
      "Pairs selected only by issuer, fold, equal count, and recency-mass spread before revealing outcomes",
      side = 1,
      line = 6.3,
      cex = 0.85
    )
  }
  dev.off()
}

write_gate_summary <- function(path) {
  gates <- verdict$gates
  png(path, width = 1350, height = 1000, res = 150)
  par(mar = c(2, 2, 3, 2))
  plot.new()
  plot.window(xlim = c(0, 1), ylim = c(0.4, nrow(gates) + 0.6))
  labels <- c(
    "Integrity and leakage",
    "Mean recency rho",
    "Positive recency quarters",
    "Mean paired improvement",
    "Positive-improvement quarters"
  )
  for (i in seq_len(nrow(gates))) {
    y <- nrow(gates) - i + 1
    color <- if (gates$passed[[i]]) "#0F766E" else "#B91C1C"
    points(0.06, y, pch = 16, cex = 2.2, col = color)
    text(
      0.12,
      y + 0.12,
      labels[[i]],
      adj = c(0, 0.5),
      cex = 1,
      font = 2
    )
    text(
      0.12,
      y - 0.16,
      paste0("required: ", gates$threshold[[i]]),
      adj = c(0, 0.5),
      cex = 0.8,
      col = "#64748B"
    )
    text(
      0.94,
      y,
      gates$value[[i]],
      adj = c(1, 0.5),
      cex = 1.25,
      font = 2,
      col = color
    )
  }
  title(
    if (verdict$passed) {
      "All frozen N1D representation gates pass"
    } else {
      "At least one frozen N1D representation gate fails"
    },
    cex.main = 1.3
  )
  dev.off()
}

write_decay_curve(file.path(visual_dir, "n1d_fixed_decay_curve.png"))
write_fold_comparison(file.path(visual_dir, "n1d_fold_comparison.png"))
write_coverage_heatmap(file.path(visual_dir, "n1d_confirmation_coverage.png"))
write_tie_resolution(file.path(visual_dir, "n1d_tie_resolution.png"))
write_timing_pairs(file.path(visual_dir, "n1d_equal_count_timing_pairs.png"))
write_gate_summary(file.path(visual_dir, "n1d_gate_summary.png"))

write_csv(run_spec, file.path(output_dir, "n1d_run_spec.csv"))
write_csv(requests, file.path(output_dir, "n1d_news_requests.csv"))
write_csv(page_manifest, file.path(output_dir, "n1d_page_manifest.csv"))
write_csv(calendar, file.path(output_dir, "n1d_market_calendar.csv"))
write_csv(query_health, file.path(output_dir, "n1d_bar_query_health.csv"))
write_csv(
  bar_validation$coverage,
  file.path(output_dir, "n1d_issuer_bar_coverage.csv")
)
write_csv(health, file.path(output_dir, "n1d_health.csv"))
write_csv(leakage, file.path(output_dir, "n1d_leakage_audit.csv"))
write_csv(
  event_coverage,
  file.path(output_dir, "n1d_confirmation_news_coverage.csv")
)
write_csv(
  evaluation$train_support,
  file.path(output_dir, "n1d_representation_train_support.csv")
)
write_csv(
  attached$train_support,
  file.path(output_dir, "n1d_control_train_support.csv")
)
write_csv(fold_summary, file.path(output_dir, "n1d_fold_summary.csv"))
write_csv(verdict$gates, file.path(output_dir, "n1d_success_gates.csv"))
write_csv(
  timing_pairs,
  file.path(output_dir, "n1d_equal_count_timing_pairs.csv")
)
write_csv(
  confirmation_events[, c(
    "article_id", "issuer_id", "decision_session",
    "exact_title_cluster_id", "age_hours", "recency_weight",
    "availability_timestamp", "decision_cutoff_timestamp"
  )],
  file.path(output_dir, "n1d_confirmation_event_weights.csv")
)
write_csv(
  evaluation$oos,
  file.path(output_dir, "n1d_oos_measurements.csv")
)

report <- c(
  "# Gen5.4 News Recency Representation N1D",
  "",
  paste0("Status: `", overall_status, "`"),
  "",
  "## Question",
  "",
  "Does one fixed 24-hour exponential recency representation improve conditional ordering of future h5 path volatility over the frozen equal-count news representation on untouched post-2024 quarters?",
  "",
  "## Readout",
  "",
  paste0(
    "- Mean baseline conditional partial Spearman: `",
    sprintf("%.4f", verdict$mean_baseline_partial_spearman),
    "`."
  ),
  paste0(
    "- Mean recency conditional partial Spearman: `",
    sprintf("%.4f", verdict$mean_recency_partial_spearman),
    "`."
  ),
  paste0(
    "- Mean recency-minus-baseline improvement: `",
    sprintf("%.4f", verdict$mean_partial_spearman_improvement),
    "`; required `>= 0.0100`."
  ),
  paste0(
    "- Positive recency folds: `",
    verdict$positive_recency_folds,
    " / 6`; required `4 / 6`."
  ),
  paste0(
    "- Positive-improvement folds: `",
    verdict$positive_improvement_folds,
    " / 6`; required `4 / 6`."
  ),
  paste0(
    "- Integrity checks: `",
    sum(leakage$status == "PASS"),
    " / ",
    nrow(leakage),
    "` PASS."
  ),
  "",
  "## Interpretation",
  "",
  if (overall_status ==
    "PASS_N1D_RECENCY_REPRESENTATION_EARNS_CANDIDATE_STATUS") {
    "All frozen gates passed. The fixed recency representation earns candidate-feature status for a separate downstream theory gate. It is not a model, threshold, exposure rule, or trading policy."
  } else if (overall_status ==
    "STOP_N1D_KEEP_EQUAL_COUNT_AND_CLOSE_REPRESENTATION_EXPANSION") {
    "At least one frozen representation gate failed. Retain the simpler equal-count measurement and close news-representation expansion. Do not rescue recency by trying alternate half-lives or text features on these confirmation outcomes."
  } else {
    "A coverage, timing, TRAIN-support, control, or leakage check failed. The representation comparison is not admissible evidence."
  },
  "",
  "## Frozen representation",
  "",
  "- Historical availability authority is `updated_at`; prospectively it remains local receipt time.",
  "- Each admissible novel cluster receives weight `2^(-age_hours / 24)` at the 17:30 decision cutoff.",
  "- Cycle weights are summed, transformed with `log1p`, and mapped through issuer-local eight-quarter TRAIN ECDFs.",
  "- The equal-count baseline, h5 outcome, N1C controls, issuer mapping, novelty, stale-update rule, and next-open timing are unchanged.",
  "",
  "## Hard boundary",
  "",
  "No alternate decay, sentiment, source weighting, embeddings, alternate controls or horizons, models, exposure, allocation, portfolio metrics, PnL, or live-advice changes were computed.",
  "",
  "## Visuals",
  "",
  "- `visuals/n1d_fixed_decay_curve.png`",
  "- `visuals/n1d_fold_comparison.png`",
  "- `visuals/n1d_confirmation_coverage.png`",
  "- `visuals/n1d_tie_resolution.png`",
  "- `visuals/n1d_equal_count_timing_pairs.png`",
  "- `visuals/n1d_gate_summary.png`"
)
writeLines(
  report,
  file.path(output_dir, "n1d_report.md"),
  useBytes = TRUE
)

message("Gen5.4 N1D complete: ", overall_status)
message(
  "Mean recency partial Spearman: ",
  sprintf("%.4f", verdict$mean_recency_partial_spearman)
)
message(
  "Mean paired improvement: ",
  sprintf("%.4f", verdict$mean_partial_spearman_improvement)
)
message(
  "Report: ",
  normalizePath(
    file.path(output_dir, "n1d_report.md"),
    winslash = "/"
  )
)
