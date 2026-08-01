# Point-in-time LIT-MOM-01.1 / STOCK_ATLAS_02_HIGH_BETA_2016 replication.

g5_mom_high_beta_atlas_id <- function() {
  "LIT-MOM-01.1/STOCK_ATLAS_02_HIGH_BETA_2016"
}

g5_mom_high_beta_expected_sector_counts <- function() {
  c(
    "Consumer Discretionary" = 8L,
    "Energy" = 25L,
    "Financials" = 32L,
    "Health Care" = 7L,
    "Industrials" = 4L,
    "Information Technology" = 14L,
    "Materials" = 6L,
    "Real Estate" = 2L,
    "Telecommunication Services" = 1L
  )
}

g5_mom_high_beta_validate_registry <- function(registry) {
  required <- c(
    "instance_id", "symbol", "company_name", "sector", "subindustry",
    "panel_role", "rationale", "source_report_date", "source_value_usd",
    "source_url"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mom01_stop(paste(
      "High-beta registry is missing:", paste(missing, collapse = ", ")
    ))
  }
  registry <- registry[, required, drop = FALSE]
  registry$source_report_date <- as.Date(registry$source_report_date)
  registry$source_value_usd <- as.numeric(registry$source_value_usd)
  expected_counts <- g5_mom_high_beta_expected_sector_counts()
  observed_counts <- table(registry$sector)
  counts_match <- identical(
    as.integer(observed_counts[names(expected_counts)]),
    as.integer(expected_counts)
  ) && identical(sort(names(observed_counts)), sort(names(expected_counts)))
  text_fields <- setdiff(required, c("source_report_date", "source_value_usd"))
  nonempty <- vapply(
    text_fields,
    function(field) all(!is.na(registry[[field]]) & nzchar(trimws(registry[[field]]))),
    logical(1)
  )
  checks <- data.frame(
    check_id = c(
      "row_count_99",
      "unique_instance_ids",
      "unique_symbols",
      "uppercase_historical_symbols",
      "nine_source_sectors",
      "source_sector_counts",
      "source_date_2016_10_31",
      "positive_source_values",
      "source_role_frozen",
      "single_sec_source",
      "nonempty_metadata"
    ),
    passed = c(
      nrow(registry) == 99L,
      !anyDuplicated(registry$instance_id),
      !anyDuplicated(registry$symbol),
      all(grepl("^[A-Z][A-Z0-9.]{0,9}$", registry$symbol)),
      identical(sort(unique(registry$sector)), sort(names(expected_counts))),
      counts_match,
      all(registry$source_report_date == as.Date("2016-10-31")),
      all(is.finite(registry$source_value_usd) & registry$source_value_usd > 0),
      all(registry$panel_role == "2016_sphb_constituent"),
      length(unique(registry$source_url)) == 1L &&
        grepl("^https://www.sec.gov/Archives/edgar/", unique(registry$source_url)),
      all(nonempty)
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_mom01_stop(paste(
      "High-beta registry failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  list(registry = registry, checks = checks)
}

g5_mom_high_beta_pretrain_beta <- function(bars, symbol, contract) {
  stock <- bars[
    bars$symbol == symbol &
      as.Date(bars$session_date) >= contract$query_start &
      as.Date(bars$session_date) < contract$train_start,
    c("session_date", "close"),
    drop = FALSE
  ]
  market <- bars[
    bars$symbol == "SPY" &
      as.Date(bars$session_date) >= contract$query_start &
      as.Date(bars$session_date) < contract$train_start,
    c("session_date", "close"),
    drop = FALSE
  ]
  names(stock)[[2L]] <- "stock_close"
  names(market)[[2L]] <- "market_close"
  aligned <- merge(stock, market, by = "session_date", all = FALSE)
  aligned <- aligned[order(as.Date(aligned$session_date)), , drop = FALSE]
  if (nrow(aligned) < 3L) {
    return(c(observations = 0, beta = NA_real_))
  }
  stock_return <- diff(log(aligned$stock_close))
  market_return <- diff(log(aligned$market_close))
  keep <- is.finite(stock_return) & is.finite(market_return)
  stock_return <- stock_return[keep]
  market_return <- market_return[keep]
  beta <- if (length(stock_return) >= 20L && stats::var(market_return) > 0) {
    stats::cov(stock_return, market_return) / stats::var(market_return)
  } else {
    NA_real_
  }
  c(observations = length(stock_return), beta = beta)
}

g5_mom_high_beta_coverage_audit <- function(bars, registry, contract) {
  spy_dates <- sort(unique(as.Date(bars$session_date[bars$symbol == "SPY"])))
  if (!length(spy_dates) ||
      min(spy_dates) > contract$query_start ||
      max(spy_dates) < contract$development_end) {
    g5_mom01_stop("SPY does not cover the frozen high-beta evidence window.")
  }
  expected_train <- spy_dates[
    spy_dates >= contract$query_start & spy_dates <= contract$train_end
  ]
  expected_development <- spy_dates[
    spy_dates >= contract$development_start &
      spy_dates <= contract$development_end
  ]
  rows <- lapply(registry$symbol, function(symbol) {
    observed <- sort(unique(as.Date(bars$session_date[bars$symbol == symbol])))
    train_observed <- observed[
      observed >= contract$query_start & observed <= contract$train_end
    ]
    development_observed <- observed[
      observed >= contract$development_start & observed <= contract$development_end
    ]
    beta <- g5_mom_high_beta_pretrain_beta(bars, symbol, contract)
    data.frame(
      symbol = symbol,
      first_observed = if (length(observed)) as.character(min(observed)) else NA_character_,
      last_observed = if (length(observed)) as.character(max(observed)) else NA_character_,
      train_observed_sessions = length(train_observed),
      train_expected_sessions = length(expected_train),
      train_missing_spy_sessions = length(setdiff(expected_train, train_observed)),
      train_coverage_exact = length(expected_train) > 0L &&
        identical(train_observed, expected_train),
      development_observed_sessions = length(development_observed),
      development_expected_sessions = length(expected_development),
      development_missing_spy_sessions = length(setdiff(
        expected_development, development_observed
      )),
      development_coverage_exact = length(expected_development) > 0L &&
        identical(development_observed, expected_development),
      pretrain_beta_observations = as.integer(beta[["observations"]]),
      pretrain_beta = unname(beta[["beta"]]),
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_mom_high_beta_train_stop_row <- function(metadata, coverage, status, message) {
  data.frame(
    instance_id = metadata$instance_id,
    symbol = metadata$symbol,
    sector = metadata$sector,
    subindustry = metadata$subindustry,
    panel_role = metadata$panel_role,
    selected_lookback = NA_integer_,
    selected_holding = NA_integer_,
    screen_pair_count = NA_integer_,
    screen_correlation = NA_real_,
    screen_p_value = NA_real_,
    screen_t_statistic = NA_real_,
    direction_accuracy = NA_real_,
    completed_sleeves = NA_integer_,
    primary_cumulative_return = NA_real_,
    primary_adjusted_sharpe = NA_real_,
    primary_maximum_drawdown = NA_real_,
    stress_cumulative_return = NA_real_,
    positive_years = NA_integer_,
    gates_passed = NA_integer_,
    train_pass = FALSE,
    canonical_pair_count = NA_integer_,
    canonical_correlation = NA_real_,
    canonical_p_value = NA_real_,
    canonical_direction_accuracy = NA_real_,
    canonical_primary_cumulative_return = NA_real_,
    pretrain_beta = coverage$pretrain_beta,
    analysis_status = status,
    analysis_message = message,
    stringsAsFactors = FALSE
  )
}

g5_mom_high_beta_bind <- function(rows) {
  rows <- Filter(function(x) !is.null(x) && nrow(x), rows)
  if (!length(rows)) data.frame() else do.call(rbind, rows)
}

g5_mom_high_beta_run_atlas <- function(bars, registry) {
  checked_registry <- g5_mom_high_beta_validate_registry(registry)
  registry <- checked_registry$registry
  base_contract <- g5_mom01_contract()
  coverage <- g5_mom_high_beta_coverage_audit(bars, registry, base_contract)
  train_summaries <- vector("list", nrow(registry))
  gate_rows <- list()
  horizon_rows <- list()
  train_bars <- list()
  train_years <- list()
  train_sleeves <- list()
  development_summaries <- list()
  development_bars <- list()
  development_years <- list()
  development_sleeves <- list()
  result_rows <- vector("list", nrow(registry))

  for (i in seq_len(nrow(registry))) {
    metadata <- registry[i, , drop = FALSE]
    symbol_coverage <- coverage[coverage$symbol == metadata$symbol, , drop = FALSE]
    if (!isTRUE(symbol_coverage$train_coverage_exact)) {
      train_summaries[[i]] <- g5_mom_high_beta_train_stop_row(
        metadata,
        symbol_coverage,
        "TRAIN_COVERAGE_STOP",
        paste(symbol_coverage$train_missing_spy_sessions, "missing SPY sessions")
      )
      result_rows[[i]] <- list(train = NULL, development = NULL)
      next
    }

    contract <- g5_mom01_replication_contract(
      metadata$symbol,
      replication_batch = "STOCK_ATLAS_02_HIGH_BETA_2016"
    )
    train_result <- tryCatch(
      g5_mom01_run_train(bars, contract),
      error = function(error) error
    )
    if (inherits(train_result, "error")) {
      train_summaries[[i]] <- g5_mom_high_beta_train_stop_row(
        metadata,
        symbol_coverage,
        "TRAIN_ANALYSIS_ERROR",
        conditionMessage(train_result)
      )
      result_rows[[i]] <- list(train = train_result, development = NULL)
      next
    }

    train_summary <- g5_mom_stock_train_summary(train_result, metadata)
    train_summary$pretrain_beta <- symbol_coverage$pretrain_beta
    train_summary$analysis_status <- if (isTRUE(train_result$development_authorized)) {
      "TRAIN_PASS"
    } else {
      "TRAIN_GATE_STOP"
    }
    train_summary$analysis_message <- train_result$overall_status
    train_summaries[[i]] <- train_summary
    key <- metadata$instance_id
    gate_rows[[key]] <- g5_mom_stock_prefix_frame(
      train_result$gates, metadata, "TRAIN"
    )
    horizon_rows[[key]] <- g5_mom_stock_prefix_frame(
      train_result$horizon_screen, metadata, "TRAIN"
    )
    train_bars[[key]] <- g5_mom_stock_prefix_frame(
      train_result$train$replay[
        train_result$train$replay$cost_regime == "PRIMARY", , drop = FALSE
      ],
      metadata,
      "TRAIN"
    )
    train_years[[key]] <- g5_mom_stock_prefix_frame(
      train_result$train$calendar_years, metadata, "TRAIN"
    )
    train_sleeves[[key]] <- g5_mom_stock_prefix_frame(
      train_result$train$sleeves, metadata, "TRAIN"
    )

    development <- NULL
    if (isTRUE(train_result$development_authorized)) {
      if (isTRUE(symbol_coverage$development_coverage_exact)) {
        development <- tryCatch(
          g5_mom01_run_development(bars, train_result, contract),
          error = function(error) error
        )
        if (!inherits(development, "error")) {
          development_summary <- g5_mom_stock_development_summary(
            development, metadata
          )
          development_summary$pretrain_beta <- symbol_coverage$pretrain_beta
          development_summary$analysis_status <- "DEVELOPMENT_COMPLETE"
          development_summaries[[key]] <- development_summary
          development_bars[[key]] <- g5_mom_stock_prefix_frame(
            development$replay[
              development$replay$cost_regime == "PRIMARY", , drop = FALSE
            ],
            metadata,
            "DEVELOPMENT"
          )
          development_years[[key]] <- g5_mom_stock_prefix_frame(
            development$calendar_years, metadata, "DEVELOPMENT"
          )
          development_sleeves[[key]] <- g5_mom_stock_prefix_frame(
            development$sleeves, metadata, "DEVELOPMENT"
          )
        } else {
          train_summaries[[i]]$analysis_status <- "DEVELOPMENT_ANALYSIS_ERROR"
          train_summaries[[i]]$analysis_message <- conditionMessage(development)
        }
      } else {
        train_summaries[[i]]$analysis_status <- "DEVELOPMENT_COVERAGE_STOP"
        train_summaries[[i]]$analysis_message <- paste(
          symbol_coverage$development_missing_spy_sessions,
          "missing SPY sessions"
        )
      }
    }
    result_rows[[i]] <- list(train = train_result, development = development)
  }

  train_summary <- do.call(rbind, train_summaries)
  development_summary <- g5_mom_high_beta_bind(development_summaries)
  continuity_count <- if (nrow(development_summary)) {
    sum(
      development_summary$positive_primary_return &
        development_summary$positive_stress_return &
        development_summary$direction_above_chance &
        development_summary$positive_correlation
    )
  } else 0L
  batch_summary <- data.frame(
    atlas_id = g5_mom_high_beta_atlas_id(),
    registry_count = nrow(registry),
    sector_count = length(unique(registry$sector)),
    train_coverage_count = sum(coverage$train_coverage_exact),
    train_analyzed_count = sum(train_summary$analysis_status != "TRAIN_COVERAGE_STOP"),
    train_pass_count = sum(train_summary$train_pass),
    development_coverage_stop_count = sum(
      train_summary$analysis_status == "DEVELOPMENT_COVERAGE_STOP"
    ),
    development_run_count = nrow(development_summary),
    development_positive_primary_count = if (nrow(development_summary)) {
      sum(development_summary$positive_primary_return)
    } else 0L,
    development_positive_stress_count = if (nrow(development_summary)) {
      sum(development_summary$positive_stress_return)
    } else 0L,
    development_direction_above_chance_count = if (nrow(development_summary)) {
      sum(development_summary$direction_above_chance)
    } else 0L,
    development_all_four_continuity_count = continuity_count,
    status = "STOCK_ATLAS_02_HIGH_BETA_2016_COMPLETE",
    stringsAsFactors = FALSE
  )
  list(
    registry = registry,
    registry_checks = checked_registry$checks,
    coverage = coverage,
    results = result_rows,
    train_summary = train_summary,
    train_gates = g5_mom_high_beta_bind(gate_rows),
    horizon_screen = g5_mom_high_beta_bind(horizon_rows),
    train_bars = g5_mom_high_beta_bind(train_bars),
    train_years = g5_mom_high_beta_bind(train_years),
    train_sleeves = g5_mom_high_beta_bind(train_sleeves),
    development_summary = development_summary,
    development_bars = g5_mom_high_beta_bind(development_bars),
    development_years = g5_mom_high_beta_bind(development_years),
    development_sleeves = g5_mom_high_beta_bind(development_sleeves),
    batch_summary = batch_summary
  )
}
