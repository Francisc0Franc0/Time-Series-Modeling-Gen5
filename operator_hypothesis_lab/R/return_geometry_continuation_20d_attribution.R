rgca_stop <- function(message) {
  stop(paste0("[RETURN-GEOMETRY-CONTINUATION-ATTRIBUTION] ", message), call. = FALSE)
}

rgca_contract <- function() {
  list(
    study_id = "RETURN_GEOMETRY_CONTINUATION_20D_ATTRIBUTION_01",
    source_study_id = "RETURN_GEOMETRY_CONTINUATION_NEXT_OPEN_RULE_01",
    inherited = rgcnor_contract(),
    hold_sessions = 20L,
    rule_ids = c(
      "SIDEWAYS_ALL", "SIDEWAYS_POSITIVE",
      "SIDEWAYS_NEGATIVE", "TRENDING_ALL"
    )
  )
}

rgca_validate_contract <- function(contract = rgca_contract()) {
  inherited <- rgcnor_validate_contract(contract$inherited)
  if (!identical(contract$hold_sessions, 20L)) {
    rgca_stop("The frozen attribution hold changed from 20 sessions.")
  }
  expected_rules <- c(
    "SIDEWAYS_ALL", "SIDEWAYS_POSITIVE",
    "SIDEWAYS_NEGATIVE", "TRENDING_ALL"
  )
  if (!identical(contract$rule_ids, expected_rules)) {
    rgca_stop("The frozen sign/state attribution branches changed.")
  }
  contract$inherited <- inherited
  contract
}

rgca_rule_map <- function() {
  c(
    SIDEWAYS_ALL = "sideways_only_signal",
    SIDEWAYS_POSITIVE = "sideways_positive_signal",
    SIDEWAYS_NEGATIVE = "sideways_negative_signal",
    TRENDING_ALL = "trending_all_signal"
  )
}

rgca_construct_candidates <- function(ledger, contract = rgca_contract()) {
  contract <- rgca_validate_contract(contract)
  out <- rgcnor_construct_candidates(
    ledger,
    hold_sessions = contract$hold_sessions,
    contract = contract$inherited
  )
  out$sideways_negative_signal <- is.finite(out$prior_20_log_return) &
    out$prior_20_log_return < 0 &
    out$er20_state == contract$inherited$sideways_state
  out$trending_all_signal <- out$er20_state == contract$inherited$trending_state
  out
}

rgca_build_asset_study <- function(ledger, contract = rgca_contract()) {
  contract <- rgca_validate_contract(contract)
  candidates <- rgca_construct_candidates(ledger, contract)
  unconditional <- mean(candidates$gross_open_log_return, na.rm = TRUE)
  rules <- rgca_rule_map()
  trades <- do.call(rbind, lapply(names(rules), function(rule_id) {
    selected <- rgcnor_select_nonoverlapping(
      candidates, rules[[rule_id]], rule_id
    )
    selected$unconditional_open_log_return <- unconditional
    selected$net_excess_vs_unconditional <-
      selected$net_open_log_return - unconditional
    selected
  }))
  rownames(trades) <- NULL
  list(candidates = candidates, trades = trades)
}

rgca_rule_summary <- function(trades, contract = rgca_contract()) {
  contract <- rgca_validate_contract(contract)
  rgcnor_rule_summary(trades, rule_ids = contract$rule_ids)
}

rgca_group_rule_summary <- function(asset_rule_summary, grouping_fields) {
  required <- c(
    grouping_fields, "rule_id", "trades", "mean_net_open_log_return",
    "mean_net_excess_vs_unconditional", "probability_profitable_net"
  )
  missing <- setdiff(required, names(asset_rule_summary))
  if (length(missing)) {
    rgca_stop(paste("Asset-rule summary is missing:", paste(missing, collapse = ", ")))
  }
  key_fields <- c(grouping_fields, "rule_id")
  keys <- interaction(asset_rule_summary[key_fields], drop = TRUE, lex.order = TRUE)
  groups <- split(asset_rule_summary, keys)
  out <- do.call(rbind, lapply(groups, function(x) {
    active <- x$trades > 0L & is.finite(x$mean_net_open_log_return)
    net <- x$mean_net_open_log_return[active]
    excess <- x$mean_net_excess_vs_unconditional[active]
    data.frame(
      x[1L, key_fields, drop = FALSE],
      assets = nrow(x),
      active_assets = sum(active),
      trades = sum(x$trades, na.rm = TRUE),
      median_asset_trades = if (any(active)) stats::median(x$trades[active]) else NA_real_,
      median_asset_mean_net_log_return = if (length(net)) stats::median(net) else NA_real_,
      positive_net_asset_fraction = if (length(net)) mean(net > 0) else NA_real_,
      median_asset_excess_vs_unconditional = if (length(excess)) stats::median(excess) else NA_real_,
      positive_excess_asset_fraction = if (length(excess)) mean(excess > 0) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}

rgca_equal_sector_summary <- function(sector_rule_summary) {
  rules <- unique(as.character(sector_rule_summary$rule_id))
  out <- do.call(rbind, lapply(rules, function(rule_id) {
    x <- sector_rule_summary[sector_rule_summary$rule_id == rule_id, , drop = FALSE]
    data.frame(
      rule_id = rule_id,
      sectors = nrow(x),
      active_assets = sum(x$active_assets),
      trades = sum(x$trades),
      equal_sector_median_asset_mean_net_log_return =
        stats::median(x$median_asset_mean_net_log_return),
      equal_sector_median_asset_excess_vs_unconditional =
        stats::median(x$median_asset_excess_vs_unconditional),
      positive_net_sectors = sum(x$median_asset_mean_net_log_return > 0),
      positive_excess_sectors = sum(x$median_asset_excess_vs_unconditional > 0),
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}

rgca_event_pooled_summary <- function(trades, contract = rgca_contract()) {
  contract <- rgca_validate_contract(contract)
  out <- do.call(rbind, lapply(contract$rule_ids, function(rule_id) {
    x <- trades[trades$rule_id == rule_id, , drop = FALSE]
    data.frame(
      rule_id = rule_id,
      assets = length(unique(x$symbol)),
      trades = nrow(x),
      mean_net_open_log_return = if (nrow(x)) mean(x$net_open_log_return) else NA_real_,
      median_net_open_log_return = if (nrow(x)) stats::median(x$net_open_log_return) else NA_real_,
      probability_profitable_net = if (nrow(x)) mean(x$net_open_log_return > 0) else NA_real_,
      mean_net_excess_vs_unconditional =
        if (nrow(x)) mean(x$net_excess_vs_unconditional) else NA_real_,
      stringsAsFactors = FALSE
    )
  }))
  rownames(out) <- NULL
  out
}

rgca_pairwise_readout <- function(equal_sector_summary, event_pooled_summary) {
  value <- function(data, rule, column) {
    data[data$rule_id == rule, column, drop = TRUE][[1L]]
  }
  pairs <- list(
    c("SIDEWAYS_POSITIVE", "SIDEWAYS_NEGATIVE"),
    c("SIDEWAYS_ALL", "TRENDING_ALL"),
    c("SIDEWAYS_ALL", "SIDEWAYS_POSITIVE")
  )
  labels <- c(
    "sideways_positive_minus_negative",
    "sideways_all_minus_trending_all",
    "sideways_all_minus_positive"
  )
  do.call(rbind, Map(function(pair, label) {
    data.frame(
      contrast_id = label,
      equal_sector_net_difference =
        value(equal_sector_summary, pair[[1L]], "equal_sector_median_asset_mean_net_log_return") -
        value(equal_sector_summary, pair[[2L]], "equal_sector_median_asset_mean_net_log_return"),
      event_pooled_net_difference =
        value(event_pooled_summary, pair[[1L]], "mean_net_open_log_return") -
        value(event_pooled_summary, pair[[2L]], "mean_net_open_log_return"),
      stringsAsFactors = FALSE
    )
  }, pairs, labels))
}
