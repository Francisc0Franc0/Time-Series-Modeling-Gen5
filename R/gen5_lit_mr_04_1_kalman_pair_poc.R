# Frozen LIT-MR-04.1 EWC-on-EWA Kalman pair exercise.

g5_mr04_contract <- function() {
  list(
    literature_id = "LIT-MR-04.1",
    descriptive_name = "Kalman Dynamic-Regression Pair",
    response_symbol = "EWC",
    predictor_symbols = "EWA",
    symbols = c("EWC", "EWA"),
    as_of_timestamp = "2026-07-24 17:30:00",
    train_start = as.Date("2016-01-04"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-01"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-01"),
    warmup_sessions = 252L,
    rolling_lookback = 20L,
    delta = 0.0001,
    entry_z = 1,
    exit_z = 0,
    primary_cost_bps = 5,
    stress_cost_bps = 10,
    stress_borrow_bps_annual = 100,
    minimum_trades = 24L,
    minimum_direction_trades = 8L,
    bootstrap_count = 1000L,
    bootstrap_block_trades = 5L,
    convergence_horizon = 5L,
    convergence_block_sessions = 10L,
    trade_bootstrap_seed = 4101L,
    convergence_bootstrap_seed = 4102L,
    random_sign_seed = 4103L,
    random_sign_count = 1000L
  )
}

g5_mr04_validate_contract <- function(contract = g5_mr04_contract()) {
  frozen <- g5_mr04_contract()
  fields <- names(frozen)
  same <- vapply(fields, function(field) {
    identical(contract[[field]], frozen[[field]])
  }, logical(1))
  if (!all(same)) {
    g5_kf_stop(paste(
      "Frozen LIT-MR-04.1 contract changed:",
      paste(fields[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mr04_run_train <- function(bars, data_health_status = "PASS") {
  g5_kf_run_train(
    bars,
    g5_mr04_validate_contract(),
    data_health_status = data_health_status
  )
}
