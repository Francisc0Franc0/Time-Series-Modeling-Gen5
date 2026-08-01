# Frozen LIT-MOM-01.1 / STOCK_ATLAS_01 breadth replication.

g5_mom_stock_atlas_id <- function() "LIT-MOM-01.1/STOCK_ATLAS_01"

g5_mom_stock_atlas_expected_sectors <- function() {
  c(
    "Communication Services",
    "Consumer Discretionary",
    "Consumer Staples",
    "Energy",
    "Financials",
    "Health Care",
    "Industrials",
    "Information Technology",
    "Materials",
    "Real Estate",
    "Utilities"
  )
}

g5_mom_stock_validate_registry <- function(registry) {
  required <- c(
    "instance_id", "symbol", "sector", "subindustry", "panel_role", "rationale"
  )
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mom01_stop(paste("Stock atlas registry is missing:", paste(missing, collapse = ", ")))
  }
  registry <- registry[, required, drop = FALSE]
  text_fields <- required
  nonempty <- vapply(
    text_fields,
    function(field) all(!is.na(registry[[field]]) & nzchar(trimws(registry[[field]]))),
    logical(1)
  )
  checks <- data.frame(
    check_id = c(
      "row_count_22",
      "unique_instance_ids",
      "unique_symbols",
      "uppercase_symbols",
      "eleven_frozen_sectors",
      "two_stocks_per_sector",
      "nonempty_metadata"
    ),
    passed = c(
      nrow(registry) == 22L,
      !anyDuplicated(registry$instance_id),
      !anyDuplicated(registry$symbol),
      all(grepl("^[A-Z][A-Z0-9.]{0,9}$", registry$symbol)),
      identical(sort(unique(registry$sector)), sort(g5_mom_stock_atlas_expected_sectors())),
      all(table(registry$sector) == 2L),
      all(nonempty)
    ),
    stringsAsFactors = FALSE
  )
  checks$status <- ifelse(checks$passed, "PASS", "FAIL")
  if (!all(checks$passed)) {
    g5_mom01_stop(paste(
      "Stock atlas registry failed:",
      paste(checks$check_id[!checks$passed], collapse = ", ")
    ))
  }
  list(registry = registry, checks = checks)
}

g5_mom_stock_metric_row <- function(metrics, strategy_id) {
  row <- metrics[metrics$strategy_id == strategy_id, , drop = FALSE]
  if (nrow(row) != 1L) g5_mom01_stop(paste("Missing", strategy_id, "metric row."))
  row
}

g5_mom_stock_chan_row <- function(analysis) {
  row <- analysis$correlation_summary[
    analysis$correlation_summary$sampling_id == "CHAN_MIN_STEP",
    ,
    drop = FALSE
  ]
  if (nrow(row) != 1L) g5_mom01_stop("Missing Chan-min-step correlation row.")
  row
}

g5_mom_stock_sleeve_direction_summary <- function(sleeves) {
  labels <- c("LONG", "SHORT")
  out <- lapply(labels, function(label) {
    x <- sleeves[sleeves$direction_label == label, , drop = FALSE]
    data.frame(
      direction_label = label,
      sleeve_count = nrow(x),
      mean_primary_net_sleeve_return = if (nrow(x)) mean(x$primary_net_sleeve_return) else NA_real_,
      direction_accuracy = if (nrow(x)) mean(x$direction_correct) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

g5_mom_stock_train_summary <- function(result, metadata) {
  analysis <- result$train
  chan <- g5_mom_stock_chan_row(analysis)
  primary <- g5_mom_stock_metric_row(analysis$metrics, "PRIMARY")
  stress <- g5_mom_stock_metric_row(analysis$metrics, "STRESS")
  canon_chan <- g5_mom_stock_chan_row(result$canonical_250_25)
  canon_primary <- g5_mom_stock_metric_row(result$canonical_250_25$metrics, "PRIMARY")
  data.frame(
    instance_id = metadata$instance_id,
    symbol = metadata$symbol,
    sector = metadata$sector,
    subindustry = metadata$subindustry,
    panel_role = metadata$panel_role,
    selected_lookback = result$selected_candidate$lookback_sessions,
    selected_holding = result$selected_candidate$holding_sessions,
    screen_pair_count = result$selected_candidate$pair_count,
    screen_correlation = result$selected_candidate$return_correlation,
    screen_p_value = result$selected_candidate$naive_pearson_p_value,
    screen_t_statistic = result$selected_candidate$correlation_t_statistic,
    direction_accuracy = chan$direction_accuracy,
    completed_sleeves = nrow(analysis$sleeves),
    primary_cumulative_return = primary$cumulative_return,
    primary_adjusted_sharpe = primary$autocorrelation_adjusted_sharpe,
    primary_maximum_drawdown = primary$maximum_drawdown,
    stress_cumulative_return = stress$cumulative_return,
    positive_years = sum(analysis$calendar_years$cumulative_return > 0),
    gates_passed = sum(result$gates$passed),
    train_pass = all(result$gates$passed),
    canonical_pair_count = canon_chan$pair_count,
    canonical_correlation = canon_chan$return_correlation,
    canonical_p_value = canon_chan$naive_pearson_p_value,
    canonical_direction_accuracy = canon_chan$direction_accuracy,
    canonical_primary_cumulative_return = canon_primary$cumulative_return,
    stringsAsFactors = FALSE
  )
}

g5_mom_stock_development_summary <- function(analysis, metadata) {
  chan <- g5_mom_stock_chan_row(analysis)
  strict <- analysis$correlation_summary[
    analysis$correlation_summary$sampling_id == "STRICT_FULL_PAIR_STEP",
    ,
    drop = FALSE
  ]
  primary <- g5_mom_stock_metric_row(analysis$metrics, "PRIMARY")
  stress <- g5_mom_stock_metric_row(analysis$metrics, "STRESS")
  directions <- g5_mom_stock_sleeve_direction_summary(analysis$sleeves)
  long <- directions[directions$direction_label == "LONG", , drop = FALSE]
  short <- directions[directions$direction_label == "SHORT", , drop = FALSE]
  data.frame(
    instance_id = metadata$instance_id,
    symbol = metadata$symbol,
    sector = metadata$sector,
    selected_lookback = analysis$lookback_sessions,
    selected_holding = analysis$holding_sessions,
    pair_count = chan$pair_count,
    correlation = chan$return_correlation,
    p_value = chan$naive_pearson_p_value,
    direction_accuracy = chan$direction_accuracy,
    strict_pair_count = strict$pair_count,
    strict_correlation = strict$return_correlation,
    completed_sleeves = nrow(analysis$sleeves),
    primary_cumulative_return = primary$cumulative_return,
    primary_adjusted_sharpe = primary$autocorrelation_adjusted_sharpe,
    primary_maximum_drawdown = primary$maximum_drawdown,
    stress_cumulative_return = stress$cumulative_return,
    long_sleeves = long$sleeve_count,
    long_mean_primary_return = long$mean_primary_net_sleeve_return,
    long_direction_accuracy = long$direction_accuracy,
    short_sleeves = short$sleeve_count,
    short_mean_primary_return = short$mean_primary_net_sleeve_return,
    short_direction_accuracy = short$direction_accuracy,
    positive_primary_return = primary$cumulative_return > 0,
    positive_stress_return = stress$cumulative_return > 0,
    direction_above_chance = chan$direction_accuracy > 0.5,
    positive_correlation = chan$return_correlation > 0,
    stringsAsFactors = FALSE
  )
}

g5_mom_stock_prefix_frame <- function(frame, metadata, period_id = NULL) {
  if (!is.null(period_id) && "period_id" %in% names(frame)) {
    frame$period_id <- NULL
  }
  prefix <- data.frame(
    instance_id = rep(metadata$instance_id, nrow(frame)),
    symbol = rep(metadata$symbol, nrow(frame)),
    sector = rep(metadata$sector, nrow(frame)),
    stringsAsFactors = FALSE
  )
  if (!is.null(period_id)) prefix$period_id <- rep(period_id, nrow(frame))
  data.frame(prefix, frame, check.names = FALSE, stringsAsFactors = FALSE)
}

g5_mom_stock_run_atlas <- function(bars, registry) {
  checked_registry <- g5_mom_stock_validate_registry(registry)
  registry <- checked_registry$registry
  results <- vector("list", nrow(registry))
  names(results) <- registry$instance_id
  train_summaries <- vector("list", nrow(registry))
  gate_rows <- vector("list", nrow(registry))
  horizon_rows <- vector("list", nrow(registry))
  development_summaries <- list()
  train_bars <- vector("list", nrow(registry))
  train_years <- vector("list", nrow(registry))
  train_sleeves <- vector("list", nrow(registry))
  development_bars <- list()
  development_years <- list()
  development_sleeves <- list()

  for (i in seq_len(nrow(registry))) {
    metadata <- registry[i, , drop = FALSE]
    contract <- g5_mom01_replication_contract(metadata$symbol)
    train_result <- g5_mom01_run_train(bars, contract)
    train_summaries[[i]] <- g5_mom_stock_train_summary(train_result, metadata)
    gate_rows[[i]] <- g5_mom_stock_prefix_frame(train_result$gates, metadata, "TRAIN")
    horizon_rows[[i]] <- g5_mom_stock_prefix_frame(
      train_result$horizon_screen,
      metadata,
      "TRAIN"
    )
    train_bars[[i]] <- g5_mom_stock_prefix_frame(
      train_result$train$replay[
        train_result$train$replay$cost_regime == "PRIMARY",
        ,
        drop = FALSE
      ],
      metadata,
      "TRAIN"
    )
    train_years[[i]] <- g5_mom_stock_prefix_frame(
      train_result$train$calendar_years,
      metadata,
      "TRAIN"
    )
    train_sleeves[[i]] <- g5_mom_stock_prefix_frame(
      train_result$train$sleeves,
      metadata,
      "TRAIN"
    )
    result <- list(train = train_result, development = NULL)
    if (isTRUE(train_result$development_authorized)) {
      development <- g5_mom01_run_development(bars, train_result, contract)
      result$development <- development
      development_summaries[[metadata$instance_id]] <-
        g5_mom_stock_development_summary(development, metadata)
      development_bars[[metadata$instance_id]] <- g5_mom_stock_prefix_frame(
        development$replay[development$replay$cost_regime == "PRIMARY", , drop = FALSE],
        metadata,
        "DEVELOPMENT"
      )
      development_years[[metadata$instance_id]] <- g5_mom_stock_prefix_frame(
        development$calendar_years,
        metadata,
        "DEVELOPMENT"
      )
      development_sleeves[[metadata$instance_id]] <- g5_mom_stock_prefix_frame(
        development$sleeves,
        metadata,
        "DEVELOPMENT"
      )
    }
    results[[i]] <- result
  }

  train_summary <- do.call(rbind, train_summaries)
  development_summary <- if (length(development_summaries)) {
    do.call(rbind, development_summaries)
  } else {
    data.frame()
  }
  continuity_count <- if (nrow(development_summary)) {
    sum(
      development_summary$positive_primary_return &
        development_summary$positive_stress_return &
        development_summary$direction_above_chance &
        development_summary$positive_correlation
    )
  } else 0L
  batch_summary <- data.frame(
    atlas_id = g5_mom_stock_atlas_id(),
    stock_count = nrow(registry),
    sector_count = length(unique(registry$sector)),
    train_pass_count = sum(train_summary$train_pass),
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
    status = "STOCK_ATLAS_01_COMPLETE",
    stringsAsFactors = FALSE
  )
  list(
    registry = registry,
    registry_checks = checked_registry$checks,
    results = results,
    train_summary = train_summary,
    train_gates = do.call(rbind, gate_rows),
    horizon_screen = do.call(rbind, horizon_rows),
    train_bars = do.call(rbind, train_bars),
    train_years = do.call(rbind, train_years),
    train_sleeves = do.call(rbind, train_sleeves),
    development_summary = development_summary,
    development_bars = if (length(development_bars)) do.call(rbind, development_bars) else data.frame(),
    development_years = if (length(development_years)) do.call(rbind, development_years) else data.frame(),
    development_sleeves = if (length(development_sleeves)) do.call(rbind, development_sleeves) else data.frame(),
    batch_summary = batch_summary
  )
}
