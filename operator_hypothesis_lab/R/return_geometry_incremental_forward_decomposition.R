rgifd_stop <- function(message) {
  stop(paste0("[RETURN-GEOMETRY-INCREMENTAL-FORWARD] ", message), call. = FALSE)
}

rgifd_contract <- function() {
  list(
    study_id = "RETURN_GEOMETRY_INCREMENTAL_FORWARD_DECOMPOSITION_01",
    analysis_start = as.Date("2018-01-02"),
    analysis_end = as.Date("2023-12-29"),
    as_of_timestamp = "2026-08-27 17:30:00 America/New_York",
    prior_sessions = 20L,
    maximum_forward_sessions = 100L,
    state_column = "signed_er20_state",
    state = "DOWN_TREND",
    minimum_observations = 30L,
    late_block_ids = c("B21_40", "B41_60", "B61_100"),
    minimum_supportive_late_blocks = 2L,
    minimum_negative_sectors = 7L,
    expected_assets = 129L,
    expected_core_assets = 88L,
    expected_sectors = 11L
  )
}

rgifd_block_registry <- function() {
  data.frame(
    block_order = seq_len(6L),
    block_id = c("B01_05", "B06_10", "B11_20", "B21_40", "B41_60", "B61_100"),
    block_label = c("1-5", "6-10", "11-20", "21-40", "41-60", "61-100"),
    block_start = c(1L, 6L, 11L, 21L, 41L, 61L),
    block_end = c(5L, 10L, 20L, 40L, 60L, 100L),
    block_sessions = c(5L, 5L, 10L, 20L, 20L, 40L),
    stringsAsFactors = FALSE
  )
}

rgifd_validate_blocks <- function(blocks = rgifd_block_registry(),
                                  contract = rgifd_contract()) {
  required <- c(
    "block_order", "block_id", "block_label", "block_start", "block_end",
    "block_sessions"
  )
  missing <- setdiff(required, names(blocks))
  if (length(missing)) rgifd_stop(paste("Block registry is missing:", paste(missing, collapse = ", ")))
  x <- blocks[required]
  integer_fields <- c("block_order", "block_start", "block_end", "block_sessions")
  x[integer_fields] <- lapply(x[integer_fields], as.integer)
  x$block_id <- as.character(x$block_id)
  x$block_label <- as.character(x$block_label)
  x <- x[order(x$block_order), , drop = FALSE]
  rownames(x) <- NULL
  if (!identical(x$block_order, seq_len(nrow(x))) || anyDuplicated(x$block_id)) {
    rgifd_stop("Block identities or ordering changed.")
  }
  if (x$block_start[[1L]] != 1L ||
      any(x$block_start[-1L] != x$block_end[-nrow(x)] + 1L) ||
      any(x$block_sessions != x$block_end - x$block_start + 1L) ||
      x$block_end[[nrow(x)]] != contract$maximum_forward_sessions) {
    rgifd_stop("Blocks must partition sessions 1 through the frozen maximum without gaps or overlap.")
  }
  x
}

rgifd_construct_surface <- function(ledger, contract = rgifd_contract(),
                                    blocks = rgifd_block_registry()) {
  blocks <- rgifd_validate_blocks(blocks, contract)
  required <- c("symbol", "session_date", "close", contract$state_column)
  missing <- setdiff(required, names(ledger))
  if (length(missing)) rgifd_stop(paste("Ledger is missing:", paste(missing, collapse = ", ")))
  if (nrow(ledger) <= contract$prior_sessions + contract$maximum_forward_sessions) {
    rgifd_stop("Ledger is too short for the frozen common-anchor surface.")
  }
  if (anyDuplicated(ledger$session_date) || any(diff(as.Date(ledger$session_date)) <= 0) ||
      any(!is.finite(ledger$close)) || any(ledger$close <= 0)) {
    rgifd_stop("Ledger dates or closes are invalid.")
  }

  anchors <- seq_len(nrow(ledger))
  usable <- anchors - contract$prior_sessions >= 1L &
    anchors + contract$maximum_forward_sessions <= nrow(ledger)
  anchors <- anchors[usable]
  keep <- as.Date(ledger$session_date[anchors]) >= contract$analysis_start &
    as.Date(ledger$session_date[anchors + contract$maximum_forward_sessions]) <= contract$analysis_end
  anchors <- anchors[keep]
  if (!length(anchors)) rgifd_stop("No common anchors cover the complete 100-session forward surface.")

  prior_return <- log(
    ledger$close[anchors] / ledger$close[anchors - contract$prior_sessions]
  )
  rows <- vector("list", nrow(blocks))
  for (i in seq_len(nrow(blocks))) {
    start_offset <- blocks$block_start[[i]] - 1L
    end_offset <- blocks$block_end[[i]]
    rows[[i]] <- data.frame(
      symbol = as.character(ledger$symbol[anchors]),
      anchor_session = as.Date(ledger$session_date[anchors]),
      common_forward_end_session = as.Date(
        ledger$session_date[anchors + contract$maximum_forward_sessions]
      ),
      prior_cumulative_log_return = prior_return,
      signed_er20_state = as.character(ledger[[contract$state_column]][anchors]),
      block_order = blocks$block_order[[i]],
      block_id = blocks$block_id[[i]],
      block_label = blocks$block_label[[i]],
      block_start = blocks$block_start[[i]],
      block_end = blocks$block_end[[i]],
      block_sessions = blocks$block_sessions[[i]],
      block_reference_session = as.Date(ledger$session_date[anchors + start_offset]),
      block_end_session = as.Date(ledger$session_date[anchors + end_offset]),
      forward_incremental_log_return = log(
        ledger$close[anchors + end_offset] / ledger$close[anchors + start_offset]
      ),
      forward_cumulative_log_return = log(
        ledger$close[anchors + end_offset] / ledger$close[anchors]
      ),
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$anchor_session, out$block_order), , drop = FALSE]
}

rgifd_sample_metrics <- function(sample, return_field, minimum_observations) {
  x <- sample$prior_cumulative_log_return
  y <- sample[[return_field]]
  complete <- is.finite(x) & is.finite(y)
  x <- x[complete]
  y <- y[complete]
  n <- length(y)
  estimable <- n >= minimum_observations && stats::sd(x) > 0 && stats::sd(y) > 0
  list(
    observations = n,
    pearson = if (estimable) stats::cor(x, y) else NA_real_,
    spearman = if (estimable) suppressWarnings(stats::cor(x, y, method = "spearman")) else NA_real_,
    slope = if (estimable) unname(stats::coef(stats::lm(y ~ x))[["x"]]) else NA_real_,
    mean = if (n) mean(y) else NA_real_,
    probability_up = if (n) mean(y > 0) else NA_real_
  )
}

rgifd_measure_asset <- function(surface, contract = rgifd_contract(),
                                blocks = rgifd_block_registry()) {
  blocks <- rgifd_validate_blocks(blocks, contract)
  rows <- vector("list", nrow(blocks))
  for (i in seq_len(nrow(blocks))) {
    block <- blocks[i, , drop = FALSE]
    x <- surface[surface$block_id == block$block_id, , drop = FALSE]
    primary <- x[
      !is.na(x$signed_er20_state) & x$signed_er20_state == contract$state &
        x$prior_cumulative_log_return < 0,
      , drop = FALSE
    ]
    unfiltered_loss <- x[x$prior_cumulative_log_return < 0, , drop = FALSE]
    unconditional <- x

    primary_incremental <- rgifd_sample_metrics(
      primary, "forward_incremental_log_return", contract$minimum_observations
    )
    primary_cumulative <- rgifd_sample_metrics(
      primary, "forward_cumulative_log_return", contract$minimum_observations
    )
    unfiltered_incremental <- rgifd_sample_metrics(
      unfiltered_loss, "forward_incremental_log_return", contract$minimum_observations
    )
    unfiltered_cumulative <- rgifd_sample_metrics(
      unfiltered_loss, "forward_cumulative_log_return", contract$minimum_observations
    )
    unconditional_incremental <- mean(
      unconditional$forward_incremental_log_return, na.rm = TRUE
    )
    unconditional_cumulative <- mean(
      unconditional$forward_cumulative_log_return, na.rm = TRUE
    )

    rows[[i]] <- data.frame(
      symbol = as.character(x$symbol[[1L]]),
      block,
      common_anchor_observations = nrow(x),
      primary_observations = primary_incremental$observations,
      unfiltered_loss_observations = unfiltered_incremental$observations,
      primary_incremental_pearson = primary_incremental$pearson,
      primary_incremental_spearman = primary_incremental$spearman,
      primary_incremental_slope = primary_incremental$slope,
      primary_incremental_mean = primary_incremental$mean,
      primary_incremental_mean_per_session = primary_incremental$mean / block$block_sessions,
      primary_incremental_probability_up = primary_incremental$probability_up,
      primary_cumulative_pearson = primary_cumulative$pearson,
      primary_cumulative_spearman = primary_cumulative$spearman,
      primary_cumulative_slope = primary_cumulative$slope,
      primary_cumulative_mean = primary_cumulative$mean,
      primary_cumulative_mean_per_session = primary_cumulative$mean / block$block_end,
      primary_cumulative_probability_up = primary_cumulative$probability_up,
      unfiltered_loss_incremental_pearson = unfiltered_incremental$pearson,
      unfiltered_loss_cumulative_pearson = unfiltered_cumulative$pearson,
      unconditional_incremental_mean = unconditional_incremental,
      unconditional_incremental_mean_per_session = unconditional_incremental / block$block_sessions,
      unconditional_cumulative_mean = unconditional_cumulative,
      unconditional_cumulative_mean_per_session = unconditional_cumulative / block$block_end,
      incremental_excess_mean = primary_incremental$mean - unconditional_incremental,
      incremental_excess_mean_per_session = (
        primary_incremental$mean - unconditional_incremental
      ) / block$block_sessions,
      cumulative_excess_mean = primary_cumulative$mean - unconditional_cumulative,
      cumulative_excess_mean_per_session = (
        primary_cumulative$mean - unconditional_cumulative
      ) / block$block_end,
      stringsAsFactors = FALSE
    )
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

rgifd_metric_fields <- function() {
  c(
    "common_anchor_observations", "primary_observations",
    "unfiltered_loss_observations", "primary_incremental_pearson",
    "primary_incremental_spearman", "primary_incremental_slope",
    "primary_incremental_mean", "primary_incremental_mean_per_session",
    "primary_incremental_probability_up", "primary_cumulative_pearson",
    "primary_cumulative_spearman", "primary_cumulative_slope",
    "primary_cumulative_mean", "primary_cumulative_mean_per_session",
    "primary_cumulative_probability_up", "unfiltered_loss_incremental_pearson",
    "unfiltered_loss_cumulative_pearson", "unconditional_incremental_mean",
    "unconditional_incremental_mean_per_session", "unconditional_cumulative_mean",
    "unconditional_cumulative_mean_per_session", "incremental_excess_mean",
    "incremental_excess_mean_per_session", "cumulative_excess_mean",
    "cumulative_excess_mean_per_session"
  )
}

rgifd_summarize_metrics <- function(data, grouping_fields,
                                    metric_fields = rgifd_metric_fields()) {
  missing <- setdiff(c(grouping_fields, metric_fields), names(data))
  if (length(missing)) rgifd_stop(paste("Summary input is missing:", paste(missing, collapse = ", ")))
  keys <- interaction(data[grouping_fields], drop = TRUE, lex.order = TRUE)
  groups <- split(data, keys)
  out <- do.call(rbind, lapply(groups, function(x) {
    row <- x[1L, grouping_fields, drop = FALSE]
    row$units <- nrow(x)
    row$described_primary_incremental <- sum(is.finite(x$primary_incremental_pearson))
    for (field in metric_fields) {
      values <- x[[field]]
      row[[field]] <- if (any(is.finite(values))) stats::median(values[is.finite(values)]) else NA_real_
    }
    row
  }))
  rownames(out) <- NULL
  out
}

rgifd_classify_duration <- function(equal_sector, sector_summary,
                                    contract = rgifd_contract()) {
  late <- equal_sector[equal_sector$block_id %in% contract$late_block_ids, , drop = FALSE]
  sector_late <- sector_summary[sector_summary$block_id %in% contract$late_block_ids, , drop = FALSE]
  negative_sector_counts <- vapply(late$block_id, function(block_id) {
    x <- sector_late[sector_late$block_id == block_id, "primary_incremental_pearson"]
    sum(is.finite(x) & x < 0)
  }, integer(1L))
  late$negative_sectors <- negative_sector_counts
  late$supportive <- is.finite(late$primary_incremental_pearson) &
    late$primary_incremental_pearson < 0 &
    late$negative_sectors >= contract$minimum_negative_sectors &
    is.finite(late$incremental_excess_mean_per_session) &
    late$incremental_excess_mean_per_session > 0
  supportive_count <- sum(late$supportive)
  status <- if (supportive_count >= contract$minimum_supportive_late_blocks) {
    "LATE_INCREMENTAL_DURATION_RETAINS_DESCRIPTIVE_SUPPORT"
  } else if (supportive_count == 0L) {
    "EARLY_REBOUND_ECHO_NO_LATE_INCREMENTAL_SUPPORT"
  } else {
    "MIXED_INCREMENTAL_TIMING_NO_DURATION_PROMOTION"
  }
  list(status = status, supportive_late_blocks = supportive_count, late = late)
}
