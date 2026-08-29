rgcsc_stop <- function(message) {
  stop(paste0("[RETURN-GEOMETRY-CONTINUATION-CONTRAST] ", message), call. = FALSE)
}

rgcsc_contract <- function() {
  list(
    contrast_id = "RETURN_GEOMETRY_CONTINUATION_STATE_CONTRAST_01",
    source_atlas_id = "RETURN_GEOMETRY_WIDE_ATLAS_01",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    horizons = c(1L, 2L, 3L, 4L, 5L, 10L, 15L, 20L, 25L, 30L, 35L, 40L, 50L, 75L, 100L),
    condition = "ER20",
    sideways_state = "RED_SIDEWAYS",
    trending_state = "GREEN_TRENDING",
    branch = "positive_prior",
    expected_assets = 129L,
    expected_core_assets = 88L,
    expected_sectors = 11L,
    expected_cells = 225L,
    expected_incomplete_pairs = 1L,
    lead_region_horizons = c(5L, 10L, 15L, 20L)
  )
}

rgcsc_run_spec_value <- function(run_spec, field) {
  if (!all(c("field", "value") %in% names(run_spec))) {
    rgcsc_stop("The source run specification is not a field-value table.")
  }
  value <- run_spec$value[run_spec$field == field]
  if (length(value) != 1L) rgcsc_stop(paste("The source run specification lacks:", field))
  as.character(value)
}

rgcsc_validate_source <- function(cells, run_spec, contract = rgcsc_contract()) {
  required <- c(
    "condition", "state", "symbol", "positive_pearson_correlation",
    "prior_sessions", "forward_sessions", "atlas_cohort", "sector",
    "sector_balance_eligible"
  )
  missing <- setdiff(required, names(cells))
  if (length(missing)) rgcsc_stop(paste("Source cells are missing:", paste(missing, collapse = ", ")))
  if (nrow(cells) != contract$expected_assets * contract$expected_cells * 9L) {
    rgcsc_stop("The full-vocabulary source surface changed dimensions.")
  }
  if (!identical(sort(unique(as.integer(cells$prior_sessions))), contract$horizons) ||
      !identical(sort(unique(as.integer(cells$forward_sessions))), contract$horizons)) {
    rgcsc_stop("The frozen 15 by 15 horizon vocabulary changed.")
  }
  if (length(unique(cells$symbol)) != contract$expected_assets ||
      sum(!duplicated(cells$symbol[cells$sector_balance_eligible])) != contract$expected_core_assets) {
    rgcsc_stop("The frozen asset or equal-sector core count changed.")
  }
  if (!all(c(contract$sideways_state, contract$trending_state) %in%
           unique(cells$state[cells$condition == contract$condition]))) {
    rgcsc_stop("One or both frozen ER20 states are unavailable.")
  }
  analysis_window <- rgcsc_run_spec_value(run_spec, "analysis_window")
  if (!identical(analysis_window, "2018-01-02 to 2023-12-29")) {
    rgcsc_stop("The source analysis boundary changed or extends beyond 2023.")
  }
  invisible(TRUE)
}

rgcsc_prepare_pairs <- function(cells, contract = rgcsc_contract()) {
  x <- cells[
    cells$condition == contract$condition &
      cells$state %in% c(contract$sideways_state, contract$trending_state),
    c(
      "symbol", "prior_sessions", "forward_sessions", "state",
      "positive_pearson_correlation", "positive_observations", "atlas_cohort",
      "sector", "sector_balance_eligible", "instrument_type", "atlas_order"
    ),
    drop = FALSE
  ]
  x$prior_sessions <- as.integer(x$prior_sessions)
  x$forward_sessions <- as.integer(x$forward_sessions)
  x$positive_pearson_correlation <- as.numeric(x$positive_pearson_correlation)
  x$positive_observations <- as.integer(x$positive_observations)
  x$sector_balance_eligible <- as.logical(x$sector_balance_eligible)

  key <- c(
    "symbol", "prior_sessions", "forward_sessions", "atlas_cohort", "sector",
    "sector_balance_eligible", "instrument_type", "atlas_order"
  )
  sideways <- x[x$state == contract$sideways_state, c(key, "positive_pearson_correlation", "positive_observations")]
  trending <- x[x$state == contract$trending_state, c(key, "positive_pearson_correlation", "positive_observations")]
  names(sideways)[names(sideways) == "positive_pearson_correlation"] <- "sideways_positive_pearson"
  names(sideways)[names(sideways) == "positive_observations"] <- "sideways_positive_observations"
  names(trending)[names(trending) == "positive_pearson_correlation"] <- "trending_positive_pearson"
  names(trending)[names(trending) == "positive_observations"] <- "trending_positive_observations"
  if (anyDuplicated(sideways[key]) || anyDuplicated(trending[key])) {
    rgcsc_stop("The source contains duplicate asset-state-horizon rows.")
  }
  out <- merge(sideways, trending, by = key, all = TRUE, sort = FALSE)
  out$paired_status <- ifelse(
    is.finite(out$sideways_positive_pearson) & is.finite(out$trending_positive_pearson),
    "PAIRED", "INCOMPLETE"
  )
  out$sideways_minus_trending_pearson <-
    out$sideways_positive_pearson - out$trending_positive_pearson
  out <- out[order(out$atlas_order, out$prior_sessions, out$forward_sessions), ]
  rownames(out) <- NULL
  out
}

rgcsc_group_apply <- function(x, fields, fn) {
  keys <- interaction(x[fields], drop = TRUE, lex.order = TRUE)
  groups <- split(x, keys)
  out <- do.call(rbind, lapply(groups, function(group) {
    cbind(group[1L, fields, drop = FALSE], fn(group))
  }))
  rownames(out) <- NULL
  out
}

rgcsc_sector_summary <- function(pairs) {
  core <- pairs[pairs$sector_balance_eligible, , drop = FALSE]
  rgcsc_group_apply(core, c("sector", "prior_sessions", "forward_sessions"), function(x) {
    valid <- x$paired_status == "PAIRED"
    data.frame(
      assets = nrow(x),
      paired_assets = sum(valid),
      median_sideways_positive_pearson = if (any(valid)) stats::median(x$sideways_positive_pearson[valid]) else NA_real_,
      median_trending_positive_pearson = if (any(valid)) stats::median(x$trending_positive_pearson[valid]) else NA_real_,
      median_sideways_minus_trending_pearson = if (any(valid)) stats::median(x$sideways_minus_trending_pearson[valid]) else NA_real_,
      asset_sideways_advantage_fraction = if (any(valid)) mean(x$sideways_minus_trending_pearson[valid] > 0) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
}

rgcsc_equal_sector_summary <- function(sector_summary) {
  rgcsc_group_apply(sector_summary, c("prior_sessions", "forward_sessions"), function(x) {
    valid <- is.finite(x$median_sideways_minus_trending_pearson)
    data.frame(
      sectors = nrow(x),
      paired_sectors = sum(valid),
      equal_sector_median_sideways_positive_pearson = if (any(valid)) stats::median(x$median_sideways_positive_pearson[valid]) else NA_real_,
      equal_sector_median_trending_positive_pearson = if (any(valid)) stats::median(x$median_trending_positive_pearson[valid]) else NA_real_,
      equal_sector_median_sideways_minus_trending_pearson = if (any(valid)) stats::median(x$median_sideways_minus_trending_pearson[valid]) else NA_real_,
      sector_sideways_advantage_fraction = if (any(valid)) mean(x$median_sideways_minus_trending_pearson[valid] > 0) else NA_real_,
      median_within_sector_asset_advantage_fraction = if (any(valid)) stats::median(x$asset_sideways_advantage_fraction[valid]) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
}

rgcsc_cohort_summary <- function(pairs) {
  rgcsc_group_apply(pairs, c("atlas_cohort", "prior_sessions", "forward_sessions"), function(x) {
    valid <- x$paired_status == "PAIRED"
    data.frame(
      assets = nrow(x),
      paired_assets = sum(valid),
      median_sideways_positive_pearson = if (any(valid)) stats::median(x$sideways_positive_pearson[valid]) else NA_real_,
      median_trending_positive_pearson = if (any(valid)) stats::median(x$trending_positive_pearson[valid]) else NA_real_,
      median_sideways_minus_trending_pearson = if (any(valid)) stats::median(x$sideways_minus_trending_pearson[valid]) else NA_real_,
      asset_sideways_advantage_fraction = if (any(valid)) mean(x$sideways_minus_trending_pearson[valid] > 0) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
}

rgcsc_region_summary <- function(equal_sector, contract = rgcsc_contract()) {
  region <- ifelse(
    equal_sector$prior_sessions %in% 1:4 & equal_sector$forward_sessions %in% 1:4,
    "MICRO_1_4",
    ifelse(
      equal_sector$prior_sessions %in% contract$lead_region_horizons &
        equal_sector$forward_sessions %in% contract$lead_region_horizons,
      "LEAD_5_20",
      ifelse(
        equal_sector$prior_sessions %in% c(25L, 30L, 35L, 40L, 50L) &
          equal_sector$forward_sessions %in% c(25L, 30L, 35L, 40L, 50L),
        "INTERMEDIATE_25_50",
        ifelse(
          equal_sector$prior_sessions %in% c(75L, 100L) &
            equal_sector$forward_sessions %in% c(75L, 100L),
          "LONG_75_100", "CROSS_REGION"
        )
      )
    )
  )
  x <- equal_sector
  x$region <- region
  rgcsc_group_apply(x, "region", function(group) {
    data.frame(
      cells = nrow(group),
      median_sideways_positive_pearson = stats::median(group$equal_sector_median_sideways_positive_pearson),
      median_trending_positive_pearson = stats::median(group$equal_sector_median_trending_positive_pearson),
      median_sideways_minus_trending_pearson = stats::median(group$equal_sector_median_sideways_minus_trending_pearson),
      sideways_advantage_cell_fraction = mean(group$equal_sector_median_sideways_minus_trending_pearson > 0),
      median_sector_sideways_advantage_fraction = stats::median(group$sector_sideways_advantage_fraction),
      stringsAsFactors = FALSE
    )
  })
}
