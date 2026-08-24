g5_him031_stop <- function(message) stop(paste0("[HYP-IMOM-03.1] ", message), call. = FALSE)

g5_him031_contract <- function() {
  list(
    hypothesis_id = "HYP-IMOM-03.1",
    symbols = c("SMH", "QQQ", "SPY"),
    prehistory_start = as.Date("2017-09-01"),
    train_start = as.Date("2018-01-02"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2022-12-30"),
    confirmation_start = as.Date("2023-01-03"),
    confirmation_end = as.Date("2023-12-29"),
    as_of_timestamp = "2026-08-22 17:30:00 America/New_York",
    provider = "alpaca",
    feed = "sip",
    timeframe = "30Min",
    adjustment = "all",
    signal_end_slot = 2L,
    target_entry_slot = 3L,
    train_test_years = c(2019L, 2020L),
    minimum_scored_sessions = 450L,
    bootstrap_seed = 731031L,
    bootstrap_count = 2000L,
    bootstrap_expected_block = 10L,
    archive_gap_dates = as.Date(c(
      "2018-05-02", "2018-05-03", "2018-08-07", "2019-08-12", "2019-10-09",
      "2021-04-19", "2021-10-25", "2022-01-24", "2022-01-26", "2022-03-08"
    )),
    early_close_dates = as.Date(c(
      "2017-11-24",
      "2018-07-03", "2018-11-23", "2018-12-24",
      "2019-07-03", "2019-11-29", "2019-12-24",
      "2020-11-27", "2020-12-24", "2021-11-26",
      "2022-11-25", "2023-07-03", "2023-11-24"
    ))
  )
}

g5_him031_validate_contract <- function(contract = g5_him031_contract()) {
  frozen <- g5_him031_contract()
  fields <- names(frozen)
  if (!is.list(contract) || !identical(names(contract), fields)) {
    g5_him031_stop("Frozen contract structure changed.")
  }
  for (field in fields) {
    if (!identical(contract[[field]], frozen[[field]])) {
      g5_him031_stop(paste("Frozen contract changed:", field))
    }
  }
  invisible(TRUE)
}

g5_him031_prepare_bars <- function(bars, contract = g5_him031_contract()) {
  g5_him031_validate_contract(contract)
  required <- c(
    "symbol", "timestamp_utc", "session_date", "bar_slot", "open", "high",
    "low", "close", "volume", "feed", "timeframe", "adjustment"
  )
  if (!is.data.frame(bars) || !all(required %in% names(bars))) {
    g5_him031_stop("Bar schema is incomplete.")
  }
  x <- bars
  x$symbol <- toupper(trimws(as.character(x$symbol)))
  x$session_date <- as.Date(x$session_date)
  x$bar_slot <- as.integer(x$bar_slot)
  if (!identical(sort(unique(x$symbol)), sort(contract$symbols))) {
    g5_him031_stop("Bars must contain exactly SMH, QQQ, and SPY.")
  }
  if (any(is.na(x$session_date)) || min(x$session_date) < contract$prehistory_start ||
      max(x$session_date) > contract$confirmation_end) {
    g5_him031_stop("Bar dates cross the frozen evidence boundary.")
  }
  if (!all(x$feed == contract$feed) || !all(x$timeframe == contract$timeframe) ||
      !all(x$adjustment == contract$adjustment)) {
    g5_him031_stop("Provider feed, timeframe, or adjustment changed.")
  }
  price_fields <- c("open", "high", "low", "close")
  if (any(!is.finite(as.matrix(x[c(price_fields, "volume")]))) ||
      any(as.matrix(x[price_fields]) <= 0) || any(x$volume < 0)) {
    g5_him031_stop("OHLCV contains nonfinite or invalid values.")
  }
  if (any(x$high < pmax(x$open, x$close, x$low)) ||
      any(x$low > pmin(x$open, x$close, x$high))) {
    g5_him031_stop("OHLC relationships are invalid.")
  }
  x <- x[!x$session_date %in% contract$archive_gap_dates, , drop = FALSE]
  early <- x$session_date %in% contract$early_close_dates
  x <- x[(!early & x$bar_slot %in% 1:13) | (early & x$bar_slot %in% 1:7), , drop = FALSE]
  x <- x[order(x$symbol, x$timestamp_utc), , drop = FALSE]
  if (anyDuplicated(x[c("symbol", "timestamp_utc")])) {
    g5_him031_stop("Duplicate symbol timestamps detected.")
  }
  stamps <- lapply(contract$symbols, function(symbol) {
    as.numeric(x$timestamp_utc[x$symbol == symbol])
  })
  if (!identical(stamps[[1L]], stamps[[2L]]) || !identical(stamps[[2L]], stamps[[3L]])) {
    g5_him031_stop("Symbol calendars are not identical.")
  }
  x
}

g5_him031_session_value <- function(rows, slot, field) {
  value <- rows[[field]][rows$bar_slot == slot]
  if (length(value) != 1L || !is.finite(value)) g5_him031_stop("Required session slot is missing or duplicated.")
  as.numeric(value)
}

g5_him031_make_panel <- function(bars, contract = g5_him031_contract()) {
  x <- g5_him031_prepare_bars(bars, contract)
  sessions <- sort(unique(x$session_date))
  rows <- lapply(sessions, function(session_date) {
    day <- x[x$session_date == session_date, , drop = FALSE]
    expected_last <- if (session_date %in% contract$early_close_dates) 7L else 13L
    by_symbol <- lapply(contract$symbols, function(symbol) day[day$symbol == symbol, , drop = FALSE])
    if (!all(vapply(by_symbol, function(z) identical(sort(z$bar_slot), seq_len(expected_last)), logical(1)))) {
      g5_him031_stop(paste("Incomplete regular-session slots on", session_date))
    }
    names(by_symbol) <- contract$symbols
    first_hour <- vapply(by_symbol, function(z) {
      log(g5_him031_session_value(z, contract$signal_end_slot, "close") /
            g5_him031_session_value(z, 1L, "open"))
    }, numeric(1))
    remainder <- vapply(by_symbol, function(z) {
      log(g5_him031_session_value(z, expected_last, "close") /
            g5_him031_session_value(z, contract$target_entry_slot, "open"))
    }, numeric(1))
    data.frame(
      anchor_date = session_date,
      final_slot = expected_last,
      fh_smh = first_hour[["SMH"]],
      fh_qqq = first_hour[["QQQ"]],
      fh_spy = first_hour[["SPY"]],
      x_lead = first_hour[["SMH"]] - first_hour[["QQQ"]],
      rem_qqq = remainder[["QQQ"]],
      rem_spy = remainder[["SPY"]],
      y_excess = remainder[["QQQ"]] - remainder[["SPY"]],
      stringsAsFactors = FALSE
    )
  })
  panel <- do.call(rbind, rows)
  panel <- panel[order(panel$anchor_date), , drop = FALSE]
  panel$x_wrong_clock <- c(NA_real_, head(panel$x_lead, -1L))
  panel$dow <- as.POSIXlt(panel$anchor_date, tz = "UTC")$wday
  panel$year <- as.integer(format(panel$anchor_date, "%Y"))
  if (any(!panel$dow %in% 1:5)) g5_him031_stop("Non-weekday session entered the panel.")
  panel
}

g5_him031_zone <- function(panel, start_date, end_date) {
  out <- panel[panel$anchor_date >= as.Date(start_date) & panel$anchor_date <= as.Date(end_date), , drop = FALSE]
  required <- c("anchor_date", "dow", "fh_qqq", "fh_spy", "x_lead", "x_wrong_clock", "y_excess")
  if (!nrow(out) || any(!stats::complete.cases(out[required]))) g5_him031_stop("Evidence zone is empty or incomplete.")
  out
}

g5_him031_model_fields <- function(model_id) {
  definitions <- list(
    DOW_DRIFT = character(),
    OWN_MARKET = c("fh_qqq", "fh_spy"),
    LEADER = c("fh_qqq", "fh_spy", "x_lead"),
    WRONG_CLOCK = c("fh_qqq", "fh_spy", "x_wrong_clock")
  )
  if (!model_id %in% names(definitions)) g5_him031_stop("Unknown frozen model.")
  definitions[[model_id]]
}

g5_him031_design <- function(data, model_id) {
  weekday <- cbind(
    dow_tue = as.numeric(data$dow == 2L),
    dow_wed = as.numeric(data$dow == 3L),
    dow_thu = as.numeric(data$dow == 4L),
    dow_fri = as.numeric(data$dow == 5L)
  )
  fields <- g5_him031_model_fields(model_id)
  predictors <- if (length(fields)) as.matrix(data[fields]) else matrix(numeric(nrow(data) * 0L), nrow = nrow(data))
  design <- cbind(intercept = 1, weekday, predictors)
  storage.mode(design) <- "double"
  design
}

g5_him031_fit <- function(train, model_id) {
  design <- g5_him031_design(train, model_id)
  fit <- stats::lm.fit(design, train$y_excess)
  if (fit$rank != ncol(design) || any(!is.finite(fit$coefficients))) {
    g5_him031_stop(paste("Degenerate frozen model:", model_id))
  }
  coefficients <- unname(fit$coefficients)
  names(coefficients) <- colnames(design)
  coefficients
}

g5_him031_predict <- function(data, model_id, coefficients) {
  design <- g5_him031_design(data, model_id)
  if (!identical(colnames(design), names(coefficients))) g5_him031_stop("Frozen design columns changed.")
  as.numeric(design %*% coefficients)
}

g5_him031_cross_validate <- function(train, contract = g5_him031_contract()) {
  model_ids <- c("DOW_DRIFT", "OWN_MARKET", "LEADER", "WRONG_CLOCK")
  rows <- list(); z <- 1L
  for (test_year in contract$train_test_years) {
    fit_rows <- train[train$year < test_year, , drop = FALSE]
    test_rows <- train[train$year == test_year, , drop = FALSE]
    if (nrow(fit_rows) < 200L || nrow(test_rows) < 200L) g5_him031_stop("TRAIN fold support is insufficient.")
    for (model_id in model_ids) {
      coefficients <- g5_him031_fit(fit_rows, model_id)
      prediction <- g5_him031_predict(test_rows, model_id, coefficients)
      rows[[z]] <- data.frame(
        anchor_date = test_rows$anchor_date,
        fold_year = test_year,
        model_id = model_id,
        actual = test_rows$y_excess,
        prediction = prediction,
        error = test_rows$y_excess - prediction,
        stringsAsFactors = FALSE
      )
      z <- z + 1L
    }
  }
  do.call(rbind, rows)
}

g5_him031_metrics <- function(predictions) {
  rows <- lapply(split(predictions, predictions$model_id), function(x) {
    data.frame(
      model_id = x$model_id[[1L]],
      scored_sessions = nrow(x),
      mse = mean(x$error^2),
      mae = mean(abs(x$error)),
      correlation = stats::cor(x$actual, x$prediction),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out[match(c("DOW_DRIFT", "OWN_MARKET", "LEADER", "WRONG_CLOCK"), out$model_id), , drop = FALSE]
}

g5_him031_stationary_indices <- function(n, expected_block) {
  if (n < 2L || expected_block < 1L) g5_him031_stop("Invalid stationary-bootstrap dimensions.")
  p <- 1 / expected_block
  out <- integer(n)
  out[[1L]] <- sample.int(n, 1L)
  for (i in 2:n) {
    out[[i]] <- if (stats::runif(1L) < p) sample.int(n, 1L) else if (out[[i - 1L]] == n) 1L else out[[i - 1L]] + 1L
  }
  out
}

g5_him031_loss_improvement <- function(predictions, contract = g5_him031_contract(),
                                       challenger = "LEADER", reference = "OWN_MARKET") {
  a <- predictions[predictions$model_id == challenger, c("anchor_date", "error"), drop = FALSE]
  b <- predictions[predictions$model_id == reference, c("anchor_date", "error"), drop = FALSE]
  names(a)[[2L]] <- "challenger_error"; names(b)[[2L]] <- "reference_error"
  pairs <- merge(a, b, by = "anchor_date", all = FALSE, sort = TRUE)
  improvement <- pairs$reference_error^2 - pairs$challenger_error^2
  set.seed(contract$bootstrap_seed)
  boot <- replicate(contract$bootstrap_count, {
    mean(improvement[g5_him031_stationary_indices(length(improvement), contract$bootstrap_expected_block)])
  })
  data.frame(
    challenger = challenger,
    reference = reference,
    scored_sessions = length(improvement),
    mean_improvement = mean(improvement),
    q10 = unname(stats::quantile(boot, 0.10, names = FALSE)),
    median = unname(stats::quantile(boot, 0.50, names = FALSE)),
    q90 = unname(stats::quantile(boot, 0.90, names = FALSE)),
    probability_positive = mean(boot > 0),
    stringsAsFactors = FALSE
  )
}

g5_him031_train_run <- function(panel, contract = g5_him031_contract()) {
  train <- g5_him031_zone(panel, contract$train_start, contract$train_end)
  predictions <- g5_him031_cross_validate(train, contract)
  metrics <- g5_him031_metrics(predictions)
  coefficients <- lapply(c("DOW_DRIFT", "OWN_MARKET", "LEADER", "WRONG_CLOCK"), function(model_id) {
    beta <- g5_him031_fit(train, model_id)
    data.frame(model_id = model_id, term = names(beta), coefficient = unname(beta), stringsAsFactors = FALSE)
  })
  coefficients <- do.call(rbind, coefficients)
  loss <- g5_him031_loss_improvement(predictions, contract)
  get_metric <- function(model_id, field) metrics[[field]][metrics$model_id == model_id]
  leader_beta <- coefficients$coefficient[coefficients$model_id == "LEADER" & coefficients$term == "x_lead"]
  gates <- data.frame(
    gate = c("support", "positive_leader_beta", "mse_below_own_market", "mae_below_own_market", "mse_below_wrong_clock", "bootstrap_q10_positive"),
    passed = c(
      get_metric("LEADER", "scored_sessions") >= contract$minimum_scored_sessions,
      leader_beta > 0,
      get_metric("LEADER", "mse") < get_metric("OWN_MARKET", "mse"),
      get_metric("LEADER", "mae") < get_metric("OWN_MARKET", "mae"),
      get_metric("LEADER", "mse") < get_metric("WRONG_CLOCK", "mse"),
      loss$q10 > 0
    ),
    stringsAsFactors = FALSE
  )
  passed <- all(gates$passed)
  decision <- data.frame(
    status = if (passed) "TRAIN_LEAD_LAG_GATES_PASS" else "STOP_HYP_IMOM_03_1_TRAIN_LEAD_LAG_GATES_FAILED",
    train_sessions = nrow(train),
    scored_sessions = get_metric("LEADER", "scored_sessions"),
    leader_coefficient = leader_beta,
    leader_mse = get_metric("LEADER", "mse"),
    own_market_mse = get_metric("OWN_MARKET", "mse"),
    wrong_clock_mse = get_metric("WRONG_CLOCK", "mse"),
    leader_mae = get_metric("LEADER", "mae"),
    own_market_mae = get_metric("OWN_MARKET", "mae"),
    loss_improvement_q10 = loss$q10,
    loss_improvement_probability_positive = loss$probability_positive,
    development_opened = passed,
    confirmation_opened = FALSE,
    stringsAsFactors = FALSE
  )
  list(train = train, predictions = predictions, metrics = metrics, coefficients = coefficients,
       loss_improvement = loss, gates = gates, decision = decision)
}

g5_him031_locked_predictions <- function(train, development) {
  model_ids <- c("DOW_DRIFT", "OWN_MARKET", "LEADER", "WRONG_CLOCK")
  rows <- lapply(model_ids, function(model_id) {
    coefficients <- g5_him031_fit(train, model_id)
    prediction <- g5_him031_predict(development, model_id, coefficients)
    data.frame(
      anchor_date = development$anchor_date,
      model_id = model_id,
      actual = development$y_excess,
      prediction = prediction,
      error = development$y_excess - prediction,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_him031_development_run <- function(panel, train_result, contract = g5_him031_contract()) {
  if (!identical(train_result$decision$status, "TRAIN_LEAD_LAG_GATES_PASS")) {
    g5_him031_stop("DEVELOPMENT is sealed because TRAIN did not pass.")
  }
  train <- g5_him031_zone(panel, contract$train_start, contract$train_end)
  development <- g5_him031_zone(panel, contract$development_start, contract$development_end)
  predictions <- g5_him031_locked_predictions(train, development)
  metrics <- g5_him031_metrics(predictions)
  loss <- g5_him031_loss_improvement(predictions, contract)
  q <- stats::quantile(train$x_lead, c(0.25, 0.75), names = FALSE)
  bottom <- development$y_excess[development$x_lead <= q[[1L]]]
  top <- development$y_excess[development$x_lead >= q[[2L]]]
  quartile <- data.frame(
    train_q25 = q[[1L]], train_q75 = q[[2L]], bottom_count = length(bottom), top_count = length(top),
    bottom_mean_target = mean(bottom), top_mean_target = mean(top),
    top_minus_bottom = mean(top) - mean(bottom), stringsAsFactors = FALSE
  )
  get_metric <- function(model_id, field) metrics[[field]][metrics$model_id == model_id]
  gates <- data.frame(
    gate = c("mse_below_own_market", "mae_below_own_market", "mse_below_wrong_clock", "bootstrap_q10_positive", "top_minus_bottom_positive"),
    passed = c(
      get_metric("LEADER", "mse") < get_metric("OWN_MARKET", "mse"),
      get_metric("LEADER", "mae") < get_metric("OWN_MARKET", "mae"),
      get_metric("LEADER", "mse") < get_metric("WRONG_CLOCK", "mse"),
      loss$q10 > 0,
      quartile$top_minus_bottom > 0
    ), stringsAsFactors = FALSE
  )
  passed <- all(gates$passed)
  decision <- data.frame(
    status = if (passed) "DEVELOPMENT_LEAD_LAG_GATES_PASS_CONFIRMATION_SEALED" else "STOP_HYP_IMOM_03_1_DEVELOPMENT_LEAD_LAG_GATES_FAILED",
    development_sessions = nrow(development), leader_mse = get_metric("LEADER", "mse"),
    own_market_mse = get_metric("OWN_MARKET", "mse"), wrong_clock_mse = get_metric("WRONG_CLOCK", "mse"),
    leader_mae = get_metric("LEADER", "mae"), own_market_mae = get_metric("OWN_MARKET", "mae"),
    loss_improvement_q10 = loss$q10, top_minus_bottom = quartile$top_minus_bottom,
    confirmation_opened = FALSE, stringsAsFactors = FALSE
  )
  list(development = development, predictions = predictions, metrics = metrics,
       loss_improvement = loss, quartile = quartile, gates = gates, decision = decision)
}

g5_him031_source_audit <- function(panel, contract = g5_him031_contract()) {
  zones <- list(
    TRAIN = c(contract$train_start, contract$train_end),
    DEVELOPMENT = c(contract$development_start, contract$development_end),
    CONFIRMATION = c(contract$confirmation_start, contract$confirmation_end)
  )
  counts <- do.call(rbind, lapply(names(zones), function(zone) {
    x <- panel[panel$anchor_date >= zones[[zone]][[1L]] & panel$anchor_date <= zones[[zone]][[2L]], , drop = FALSE]
    data.frame(zone = zone, first_session = min(x$anchor_date), last_session = max(x$anchor_date),
               session_count = nrow(x), stringsAsFactors = FALSE)
  }))
  checks <- data.frame(
    check = c("exact_three_symbols", "causal_slot_boundary", "train_support", "development_support", "confirmation_sealed"),
    passed = c(TRUE, contract$target_entry_slot > contract$signal_end_slot,
               counts$session_count[counts$zone == "TRAIN"] >= 700L,
               counts$session_count[counts$zone == "DEVELOPMENT"] >= 450L,
               max(panel$anchor_date) <= contract$confirmation_end),
    stringsAsFactors = FALSE
  )
  list(counts = counts, checks = checks)
}
