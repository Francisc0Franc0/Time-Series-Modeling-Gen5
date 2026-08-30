rgsr_stop <- function(message) {
  stop(paste0("[SIDEWAYS-LOSS-REBOUND] ", message), call. = FALSE)
}

rgsr_contract <- function() {
  list(
    study_id = "RETURN_GEOMETRY_SIDEWAYS_LOSS_REBOUND_BASELINE_01",
    source_study_id = "RETURN_GEOMETRY_CONTINUATION_20D_ATTRIBUTION_01",
    inherited = rgca_contract(),
    hold_sessions = 20L,
    primary_rule_id = "SIDEWAYS_NEGATIVE",
    rule_ids = c(
      "SIDEWAYS_NEGATIVE", "NEGATIVE_ALL",
      "TRENDING_NEGATIVE", "SIDEWAYS_ALL"
    )
  )
}

rgsr_validate_contract <- function(contract = rgsr_contract()) {
  contract$inherited <- rgca_validate_contract(contract$inherited)
  if (!identical(contract$hold_sessions, 20L)) {
    rgsr_stop("The frozen hold changed from 20 sessions.")
  }
  expected <- c(
    "SIDEWAYS_NEGATIVE", "NEGATIVE_ALL",
    "TRENDING_NEGATIVE", "SIDEWAYS_ALL"
  )
  if (!identical(contract$rule_ids, expected) ||
      !identical(contract$primary_rule_id, "SIDEWAYS_NEGATIVE")) {
    rgsr_stop("The frozen primary rule or matched controls changed.")
  }
  contract
}

rgsr_rule_map <- function() {
  c(
    SIDEWAYS_NEGATIVE = "sideways_negative_signal",
    NEGATIVE_ALL = "negative_all_signal",
    TRENDING_NEGATIVE = "trending_negative_signal",
    SIDEWAYS_ALL = "sideways_only_signal"
  )
}

rgsr_construct_candidates <- function(ledger, contract = rgsr_contract()) {
  contract <- rgsr_validate_contract(contract)
  out <- rgca_construct_candidates(ledger, contract$inherited)
  out$negative_all_signal <- is.finite(out$prior_20_log_return) &
    out$prior_20_log_return < 0
  out$trending_negative_signal <- out$negative_all_signal &
    out$er20_state == contract$inherited$inherited$trending_state
  out
}

rgsr_build_asset_study <- function(ledger, contract = rgsr_contract()) {
  contract <- rgsr_validate_contract(contract)
  candidates <- rgsr_construct_candidates(ledger, contract)
  unconditional <- mean(candidates$gross_open_log_return, na.rm = TRUE)
  rules <- rgsr_rule_map()
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

rgsr_rule_summary <- function(trades, contract = rgsr_contract()) {
  contract <- rgsr_validate_contract(contract)
  rgcnor_rule_summary(trades, rule_ids = contract$rule_ids)
}

rgsr_event_pooled_summary <- function(trades, contract = rgsr_contract()) {
  contract <- rgsr_validate_contract(contract)
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

rgsr_direct_readout <- function(equal_sector_summary, event_pooled_summary) {
  value <- function(data, rule, column) {
    data[data$rule_id == rule, column, drop = TRUE][[1L]]
  }
  controls <- c("NEGATIVE_ALL", "TRENDING_NEGATIVE", "SIDEWAYS_ALL")
  labels <- c(
    NEGATIVE_ALL = "sideways_negative_minus_negative_all",
    TRENDING_NEGATIVE = "sideways_negative_minus_trending_negative",
    SIDEWAYS_ALL = "sideways_negative_minus_sideways_all"
  )
  do.call(rbind, lapply(controls, function(control) data.frame(
    contrast_id = labels[[control]],
    primary_rule_id = "SIDEWAYS_NEGATIVE",
    control_rule_id = control,
    equal_sector_net_difference =
      value(equal_sector_summary, "SIDEWAYS_NEGATIVE",
            "equal_sector_median_asset_mean_net_log_return") -
      value(equal_sector_summary, control,
            "equal_sector_median_asset_mean_net_log_return"),
    event_pooled_net_difference =
      value(event_pooled_summary, "SIDEWAYS_NEGATIVE",
            "mean_net_open_log_return") -
      value(event_pooled_summary, control,
            "mean_net_open_log_return"),
    stringsAsFactors = FALSE
  )))
}

rgsr_calendar_summary <- function(core_trades) {
  if (!nrow(core_trades)) return(data.frame())
  core_trades$entry_year <- as.integer(format(core_trades$entry_session, "%Y"))
  keys <- interaction(
    core_trades[c("entry_year", "rule_id")], drop = TRUE, lex.order = TRUE
  )
  groups <- split(core_trades, keys)
  out <- do.call(rbind, lapply(groups, function(x) data.frame(
    entry_year = x$entry_year[[1L]],
    rule_id = x$rule_id[[1L]],
    assets = length(unique(x$symbol)),
    trades = nrow(x),
    mean_net_open_log_return = mean(x$net_open_log_return),
    mean_net_excess_vs_unconditional = mean(x$net_excess_vs_unconditional),
    probability_profitable_net = mean(x$net_open_log_return > 0),
    stringsAsFactors = FALSE
  )))
  rownames(out) <- NULL
  out[order(out$entry_year, out$rule_id), , drop = FALSE]
}
