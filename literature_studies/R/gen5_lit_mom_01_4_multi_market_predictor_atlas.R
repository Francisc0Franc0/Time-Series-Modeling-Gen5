# Frozen LIT-MOM-01.4 multi-market predictor atlas helpers.

g5_mom014_stop <- function(message) stop(message, call. = FALSE)

g5_mom014_schema_version <- function() "gen5_lit_mom_01_4_v1"

g5_mom014_contract <- function() {
  list(
    literature_id = "LIT-MOM-01.4",
    descriptive_name = "Multi-Market Horizon-Surface Predictor Atlas",
    as_of_timestamp = "2026-08-21 17:30:00 America/New_York",
    registry_relative_path = file.path(
      "literature_studies", "registries",
      "gen5_lit_mom_02_1_opening_gap_atlas_registry.csv"
    ),
    registry_sha256 = "69C481DCB8443AADC30D8BF10FC7FFB7EC23D193CE88A992E42F8529225E4737",
    registry_count = 92L,
    query_start = as.Date("2016-01-04"),
    query_end = as.Date("2023-12-29"),
    train_start = as.Date("2017-01-03"),
    train_end = as.Date("2020-12-31"),
    development_start = as.Date("2021-01-04"),
    development_end = as.Date("2023-12-29"),
    confirmation_start = as.Date("2024-01-02"),
    confirmation_end = as.Date("2025-12-31"),
    lookback_grid = c(1L, 5L, 10L, 25L, 60L, 120L, 250L),
    target_grid = c(5L, 10L, 25L, 60L),
    common_lookback_sessions = 250L,
    common_target_sessions = 60L,
    minimum_period_anchors = 600L,
    fixed_cell_shift_minimum = 60L,
    fdr_q = 0.10,
    bootstrap_count = 10000L,
    bootstrap_expected_block = 60,
    bootstrap_seed_base = 2026082104L,
    bootstrap_quantile_type = 7L,
    spy_reference_symbol = "SPY"
  )
}

g5_mom014_validate_contract <- function(contract = g5_mom014_contract()) {
  frozen <- g5_mom014_contract()
  if (!identical(names(contract), names(frozen))) {
    g5_mom014_stop("Frozen LIT-MOM-01.4 contract field set changed.")
  }
  same <- vapply(
    names(frozen),
    function(field) identical(contract[[field]], frozen[[field]]),
    logical(1)
  )
  if (!all(same)) {
    g5_mom014_stop(paste(
      "Frozen LIT-MOM-01.4 contract changed:",
      paste(names(frozen)[!same], collapse = ", ")
    ))
  }
  contract
}

g5_mom014_file_sha256 <- function(path) {
  if (!file.exists(path)) g5_mom014_stop("Frozen registry file is missing.")
  if (.Platform$OS.type == "windows") {
    output <- system2("certutil", c("-hashfile", shQuote(path), "SHA256"), stdout = TRUE, stderr = TRUE)
    candidates <- trimws(output[grepl("^[0-9A-Fa-f ]{64,}$", trimws(output))])
    candidates <- gsub(" ", "", candidates, fixed = TRUE)
  } else {
    output <- system2("sha256sum", shQuote(path), stdout = TRUE, stderr = TRUE)
    candidates <- sub("[[:space:]].*$", "", trimws(output))
  }
  candidates <- toupper(candidates[nchar(candidates) == 64L])
  if (length(candidates) != 1L) g5_mom014_stop("Could not resolve frozen registry SHA-256.")
  candidates[[1L]]
}

g5_mom014_validate_registry <- function(registry, contract = g5_mom014_contract()) {
  contract <- g5_mom014_validate_contract(contract)
  observed_hash <- attr(registry, "sha256")
  required <- c("order", "instance_id", "symbol", "category", "instrument_type", "poc_anchor", "rationale")
  missing <- setdiff(required, names(registry))
  if (length(missing)) {
    g5_mom014_stop(paste("Registry columns missing:", paste(missing, collapse = ", ")))
  }
  registry <- registry[order(as.integer(registry$order)), required, drop = FALSE]
  registry$order <- as.integer(registry$order)
  registry$symbol <- toupper(trimws(as.character(registry$symbol)))
  checks <- c(
    nrow(registry) == contract$registry_count,
    identical(registry$order, seq_len(contract$registry_count)),
    !anyDuplicated(registry$instance_id),
    !anyDuplicated(registry$symbol),
    sum(registry$instrument_type == "ETF" & registry$category != "Leveraged or inverse ETF") == 68L,
    sum(registry$category == "Leveraged or inverse ETF") == 6L,
    sum(registry$instrument_type == "Stock") == 18L,
    sum(registry$symbol == contract$spy_reference_symbol) == 1L
  )
  if (!all(checks)) g5_mom014_stop("Frozen 92-row registry structure changed.")
  registry$analysis_id <- sprintf("A%03d", registry$order)
  registry$analysis_stratum <- ifelse(
    registry$instrument_type == "Stock", "STOCK_CHALLENGER",
    ifelse(registry$category == "Leveraged or inverse ETF", "ENGINEERED_ETF", "PLAIN_ETF")
  )
  registry$is_spy_reference <- registry$symbol == contract$spy_reference_symbol
  if (!is.null(observed_hash)) attr(registry, "sha256") <- observed_hash
  registry
}

g5_mom014_read_registry <- function(repo_root, contract = g5_mom014_contract()) {
  path <- file.path(repo_root, contract$registry_relative_path)
  observed_hash <- g5_mom014_file_sha256(path)
  if (!identical(observed_hash, contract$registry_sha256)) {
    g5_mom014_stop(paste("Frozen registry SHA-256 changed:", observed_hash))
  }
  registry <- utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
  registry$poc_anchor <- as.logical(registry$poc_anchor)
  out <- g5_mom014_validate_registry(registry, contract)
  attr(out, "sha256") <- observed_hash
  out
}

g5_mom014_validate_bars <- function(bars, registry, contract = g5_mom014_contract()) {
  contract <- g5_mom014_validate_contract(contract)
  required <- c("symbol", "session_date", "open", "close", "adjusted", "timeframe")
  missing <- setdiff(required, names(bars))
  if (length(missing)) g5_mom014_stop(paste("Bar columns missing:", paste(missing, collapse = ", ")))
  x <- bars[bars$symbol %in% registry$symbol, , drop = FALSE]
  x$symbol <- toupper(as.character(x$symbol))
  x$session_date <- as.Date(x$session_date)
  x <- x[order(match(x$symbol, registry$symbol), x$session_date), , drop = FALSE]
  if (any(x$session_date >= contract$confirmation_start)) {
    g5_mom014_stop("Confirmation bars entered the LIT-MOM-01.4 execution input.")
  }
  x
}

g5_mom014_coverage_ledger <- function(bars, registry, contract = g5_mom014_contract()) {
  rows <- lapply(seq_len(nrow(registry)), function(i) {
    symbol <- registry$symbol[[i]]
    x <- bars[bars$symbol == symbol, , drop = FALSE]
    dates <- as.Date(x$session_date)
    duplicate_count <- if (length(dates)) sum(duplicated(dates)) else 0L
    valid_prices <- nrow(x) > 0L && all(is.finite(x$open) & x$open > 0 & is.finite(x$close) & x$close > 0)
    adjusted_daily <- nrow(x) > 0L && all(x$adjusted %in% TRUE) && all(x$timeframe == "1D")
    start_covered <- length(dates) > 0L && min(dates) <= contract$query_start
    end_covered <- length(dates) > 0L && max(dates) >= contract$query_end
    data.frame(
      analysis_id = registry$analysis_id[[i]],
      symbol = symbol,
      category = registry$category[[i]],
      analysis_stratum = registry$analysis_stratum[[i]],
      is_spy_reference = registry$is_spy_reference[[i]],
      row_count = nrow(x),
      first_session = if (length(dates)) as.character(min(dates)) else NA_character_,
      last_session = if (length(dates)) as.character(max(dates)) else NA_character_,
      duplicate_session_count = duplicate_count,
      valid_positive_prices = valid_prices,
      adjusted_daily_only = adjusted_daily,
      query_start_covered = start_covered,
      query_end_covered = end_covered,
      mechanically_eligible = nrow(x) > 0L && duplicate_count == 0L && valid_prices && adjusted_daily && start_covered && end_covered,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$eligibility_reason <- vapply(seq_len(nrow(out)), function(i) {
    reasons <- character()
    if (out$row_count[[i]] == 0L) reasons <- c(reasons, "no_rows")
    if (out$duplicate_session_count[[i]] > 0L) reasons <- c(reasons, "duplicate_sessions")
    if (!out$valid_positive_prices[[i]]) reasons <- c(reasons, "invalid_prices")
    if (!out$adjusted_daily_only[[i]]) reasons <- c(reasons, "not_adjusted_daily")
    if (!out$query_start_covered[[i]]) reasons <- c(reasons, "query_start_not_covered")
    if (!out$query_end_covered[[i]]) reasons <- c(reasons, "query_end_not_covered")
    if (length(reasons)) paste(reasons, collapse = ";") else "ELIGIBLE"
  }, character(1))
  out
}

g5_mom014_period_panel <- function(
  symbol_bars, period_start, period_end,
  contract = g5_mom014_contract()
) {
  x <- symbol_bars[order(as.Date(symbol_bars$session_date)), , drop = FALSE]
  x$session_date <- as.Date(x$session_date)
  indices <- seq_len(nrow(x))
  anchor_i <- indices[
    indices > contract$common_lookback_sessions &
      indices + 1L + contract$common_target_sessions <= nrow(x) &
      x$session_date >= as.Date(period_start)
  ]
  anchor_i <- anchor_i[
    x$session_date[anchor_i + 1L + contract$common_target_sessions] <= as.Date(period_end)
  ]
  if (!length(anchor_i)) return(NULL)
  x_matrix <- vapply(contract$lookback_grid, function(lag_n) {
    log(x$close[anchor_i] / x$close[anchor_i - lag_n])
  }, numeric(length(anchor_i)))
  y_matrix <- vapply(contract$target_grid, function(horizon_n) {
    log(x$open[anchor_i + 1L + horizon_n] / x$open[anchor_i + 1L])
  }, numeric(length(anchor_i)))
  colnames(x_matrix) <- paste0("L", contract$lookback_grid)
  colnames(y_matrix) <- paste0("H", contract$target_grid)
  if (!all(is.finite(x_matrix)) || !all(is.finite(y_matrix))) {
    g5_mom014_stop("Nonfinite predictor or target values were constructed.")
  }
  list(
    bars = x,
    anchor_index = anchor_i,
    anchor_date = x$session_date[anchor_i],
    entry_date = x$session_date[anchor_i + 1L],
    maximum_exit_date = x$session_date[anchor_i + 1L + contract$common_target_sessions],
    x = x_matrix,
    y = y_matrix
  )
}

g5_mom014_cell_statistics <- function(x, y, lookback, target) {
  fit <- stats::lm.fit(cbind(1, x), y)
  rho <- stats::cor(x, y)
  data.frame(
    lookback_sessions = as.integer(lookback),
    target_sessions = as.integer(target),
    anchor_count = length(x),
    alpha = unname(fit$coefficients[[1L]]),
    beta = unname(fit$coefficients[[2L]]),
    correlation = unname(rho),
    sign_accuracy = mean(sign(x) == sign(y)),
    positive_target_frequency = mean(y > 0),
    unconditional_target_mean = mean(y),
    stringsAsFactors = FALSE
  )
}

g5_mom014_surface <- function(panel, contract = g5_mom014_contract()) {
  rows <- vector("list", length(contract$lookback_grid) * length(contract$target_grid))
  row_i <- 1L
  for (l_i in seq_along(contract$lookback_grid)) {
    for (h_i in seq_along(contract$target_grid)) {
      rows[[row_i]] <- g5_mom014_cell_statistics(
        panel$x[, l_i], panel$y[, h_i],
        contract$lookback_grid[[l_i]], contract$target_grid[[h_i]]
      )
      row_i <- row_i + 1L
    }
  }
  out <- do.call(rbind, rows)
  out$cell_id <- paste0("L", out$lookback_sessions, "_H", out$target_sessions)
  out$is_canonical_250_25 <- out$lookback_sessions == 250L & out$target_sessions == 25L
  out <- out[order(out$lookback_sessions, out$target_sessions), , drop = FALSE]
  rownames(out) <- NULL
  out
}

g5_mom014_nominate <- function(surface) {
  candidates <- surface[is.finite(surface$correlation) & surface$correlation > 0, , drop = FALSE]
  if (!nrow(candidates)) return(surface[FALSE, , drop = FALSE])
  candidates <- candidates[order(
    -candidates$correlation,
    candidates$target_sessions,
    candidates$lookback_sessions
  ), , drop = FALSE]
  out <- candidates[1L, , drop = FALSE]
  out$selection_rule <- "largest_positive_train_correlation;tie_shorter_H_then_shorter_L"
  out
}

g5_mom014_cell_pairs <- function(panel, lookback, target, contract = g5_mom014_contract()) {
  l_i <- match(as.integer(lookback), contract$lookback_grid)
  h_i <- match(as.integer(target), contract$target_grid)
  if (is.na(l_i) || is.na(h_i)) g5_mom014_stop("Requested cell is outside the frozen grid.")
  data.frame(
    anchor_date = panel$anchor_date,
    entry_date = panel$entry_date,
    outcome_date = panel$bars$session_date[panel$anchor_index + 1L + as.integer(target)],
    lookback_sessions = as.integer(lookback),
    target_sessions = as.integer(target),
    predictor_log_return = panel$x[, l_i],
    target_log_return = panel$y[, h_i],
    stringsAsFactors = FALSE
  )
}

g5_mom014_rotate <- function(x, shift) {
  n <- length(x)
  shift <- as.integer(shift) %% n
  if (!shift) return(x)
  x[c((shift + 1L):n, seq_len(shift))]
}

g5_mom014_fixed_shift_test <- function(pairs, contract = g5_mom014_contract()) {
  n <- nrow(pairs)
  shifts <- seq_len(n - 1L)
  shifts <- shifts[pmin(shifts, n - shifts) >= contract$fixed_cell_shift_minimum]
  if (!length(shifts)) g5_mom014_stop("No admissible fixed-cell circular shifts are available.")
  observed <- stats::cor(pairs$predictor_log_return, pairs$target_log_return)
  null <- vapply(shifts, function(shift) {
    stats::cor(
      pairs$predictor_log_return,
      g5_mom014_rotate(pairs$target_log_return, shift)
    )
  }, numeric(1))
  list(
    summary = data.frame(
      observed_correlation = observed,
      shift_count = length(shifts),
      minimum_displacement = contract$fixed_cell_shift_minimum,
      empirical_upper_p_value = (1 + sum(null >= observed)) / (1 + length(null)),
      null_p90 = unname(stats::quantile(null, 0.90, type = 7, names = FALSE)),
      stringsAsFactors = FALSE
    ),
    distribution = data.frame(
      shift_sessions = shifts,
      shifted_correlation = null,
      stringsAsFactors = FALSE
    )
  )
}

g5_mom014_stationary_index_matrix <- function(n, draws, expected_block) {
  probability_restart <- 1 / as.numeric(expected_block)
  indices <- matrix(NA_integer_, nrow = draws, ncol = n)
  indices[, 1L] <- sample.int(n, draws, replace = TRUE)
  if (n >= 2L) {
    for (column_i in 2:n) {
      restart <- stats::runif(draws) < probability_restart
      continued <- (indices[, column_i - 1L] %% n) + 1L
      starts <- sample.int(n, draws, replace = TRUE)
      indices[, column_i] <- ifelse(restart, starts, continued)
    }
  }
  indices
}

g5_mom014_stationary_beta <- function(pairs, seed, contract = g5_mom014_contract()) {
  x <- pairs$predictor_log_return
  y <- pairs$target_log_return
  observed <- g5_mom014_cell_statistics(
    x, y, unique(pairs$lookback_sessions), unique(pairs$target_sessions)
  )$beta
  set.seed(as.integer(seed))
  indices <- g5_mom014_stationary_index_matrix(
    length(x), contract$bootstrap_count, contract$bootstrap_expected_block
  )
  x_boot <- matrix(x[indices], nrow = contract$bootstrap_count)
  y_boot <- matrix(y[indices], nrow = contract$bootstrap_count)
  x_centered <- x_boot - rowMeans(x_boot)
  y_centered <- y_boot - rowMeans(y_boot)
  draws <- rowSums(x_centered * y_centered) / rowSums(x_centered^2)
  draws[!is.finite(draws)] <- NA_real_
  finite <- draws[is.finite(draws)]
  if (!length(finite)) g5_mom014_stop("Stationary bootstrap produced no finite beta draws.")
  data.frame(
    bootstrap_seed = as.integer(seed),
    bootstrap_draws = length(finite),
    beta_bootstrap_mean = mean(finite),
    beta_ci_lower_90 = unname(stats::quantile(finite, 0.05, type = contract$bootstrap_quantile_type)),
    beta_ci_upper_90 = unname(stats::quantile(finite, 0.95, type = contract$bootstrap_quantile_type)),
    beta_null_centered_upper_p = (1 + sum((finite - observed) >= observed)) / (1 + length(finite)),
    stringsAsFactors = FALSE
  )
}

g5_mom014_quintiles <- function(pairs) {
  breaks <- unique(stats::quantile(
    pairs$predictor_log_return, seq(0, 1, 0.2),
    names = FALSE, type = 7
  ))
  if (length(breaks) != 6L) return(data.frame())
  group <- cut(
    pairs$predictor_log_return, breaks,
    include.lowest = TRUE, labels = paste0("Q", 1:5)
  )
  groups <- split(pairs, group)
  do.call(rbind, lapply(names(groups), function(id) {
    x <- groups[[id]]
    data.frame(
      quintile = id,
      anchor_count = nrow(x),
      mean_predictor = mean(x$predictor_log_return),
      mean_target = mean(x$target_log_return),
      median_target = stats::median(x$target_log_return),
      positive_target_frequency = mean(x$target_log_return > 0),
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom014_years <- function(pairs) {
  groups <- split(pairs, format(pairs$anchor_date, "%Y"))
  do.call(rbind, lapply(names(groups), function(year_id) {
    x <- groups[[year_id]]
    data.frame(
      calendar_year = year_id,
      g5_mom014_cell_statistics(
        x$predictor_log_return, x$target_log_return,
        unique(x$lookback_sessions), unique(x$target_sessions)
      ),
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom014_phases <- function(pairs) {
  h <- unique(pairs$target_sessions)
  do.call(rbind, lapply(0:(h - 1L), function(offset) {
    x <- pairs[seq.int(offset + 1L, nrow(pairs), by = h), , drop = FALSE]
    data.frame(
      phase_offset = offset,
      g5_mom014_cell_statistics(
        x$predictor_log_return, x$target_log_return,
        unique(x$lookback_sessions), h
      ),
      stringsAsFactors = FALSE
    )
  }))
}

g5_mom014_neighbors <- function(surface, nominee, contract = g5_mom014_contract()) {
  if (!nrow(nominee)) return(surface[FALSE, , drop = FALSE])
  l_i <- match(nominee$lookback_sessions, contract$lookback_grid)
  h_i <- match(nominee$target_sessions, contract$target_grid)
  l_range <- seq.int(max(1L, l_i - 1L), min(length(contract$lookback_grid), l_i + 1L))
  h_range <- seq.int(max(1L, h_i - 1L), min(length(contract$target_grid), h_i + 1L))
  out <- surface[
    surface$lookback_sessions %in% contract$lookback_grid[l_range] &
      surface$target_sessions %in% contract$target_grid[h_range],
    , drop = FALSE
  ]
  out$is_nominee <- out$cell_id == nominee$cell_id
  out
}

g5_mom014_bind_tag <- function(x, registry_row) {
  if (!nrow(x)) return(x)
  cbind(
    analysis_id = registry_row$analysis_id,
    symbol = registry_row$symbol,
    category = registry_row$category,
    analysis_stratum = registry_row$analysis_stratum,
    x
  )
}

g5_mom014_category_summary <- function(ledger, development) {
  keys <- unique(ledger[, c("analysis_stratum", "category"), drop = FALSE])
  rows <- lapply(seq_len(nrow(keys)), function(i) {
    stratum <- keys$analysis_stratum[[i]]
    category <- keys$category[[i]]
    base <- ledger[ledger$analysis_stratum == stratum & ledger$category == category, , drop = FALSE]
    dev <- development[
      development$analysis_stratum == stratum & development$category == category,
      , drop = FALSE
    ]
    data.frame(
      analysis_stratum = stratum,
      category = category,
      registry_assets = nrow(base),
      analysis_eligible_assets = sum(base$analysis_eligible),
      train_nominees = nrow(dev),
      positive_development_rho = sum(dev$correlation > 0, na.rm = TRUE),
      fdr_candidates = sum(dev$is_development_candidate, na.rm = TRUE),
      median_development_rho = if (nrow(dev)) stats::median(dev$correlation, na.rm = TRUE) else NA_real_,
      median_development_beta = if (nrow(dev)) stats::median(dev$beta, na.rm = TRUE) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

g5_mom014_apply_fdr <- function(development, contract = g5_mom014_contract()) {
  if (!nrow(development)) return(development)
  required <- c(
    "analysis_stratum", "is_spy_reference", "empirical_upper_p_value",
    "correlation", "beta"
  )
  missing <- setdiff(required, names(development))
  if (length(missing)) g5_mom014_stop(paste("DEVELOPMENT columns missing:", paste(missing, collapse = ", ")))
  development$bh_q_value <- NA_real_
  for (stratum in unique(development$analysis_stratum)) {
    keep <- development$analysis_stratum == stratum & !development$is_spy_reference
    development$bh_q_value[keep] <- stats::p.adjust(
      development$empirical_upper_p_value[keep], method = "BH"
    )
  }
  development$is_development_candidate <-
    !development$is_spy_reference &
    development$correlation > 0 &
    development$beta > 0 &
    development$bh_q_value <= contract$fdr_q
  development
}

g5_mom014_run_atlas <- function(bars, registry, contract = g5_mom014_contract()) {
  contract <- g5_mom014_validate_contract(contract)
  registry <- g5_mom014_validate_registry(registry, contract)
  bars <- g5_mom014_validate_bars(bars, registry, contract)
  ledger <- g5_mom014_coverage_ledger(bars, registry, contract)
  ledger$train_anchor_count <- NA_integer_
  ledger$development_anchor_count <- NA_integer_
  ledger$analysis_eligible <- FALSE
  ledger$train_nomination_status <- NA_character_
  train_surfaces <- list()
  nominees <- list()
  development <- list()
  shift_distributions <- list()
  stored_pairs <- list()
  stored_panels <- list()
  stored_surfaces <- list()

  for (asset_i in seq_len(nrow(registry))) {
    registry_row <- registry[asset_i, , drop = FALSE]
    ledger_i <- match(registry_row$analysis_id, ledger$analysis_id)
    if (!ledger$mechanically_eligible[[ledger_i]]) next
    symbol_bars <- bars[bars$symbol == registry_row$symbol, , drop = FALSE]
    train_panel <- g5_mom014_period_panel(
      symbol_bars, contract$train_start, contract$train_end, contract
    )
    development_panel <- g5_mom014_period_panel(
      symbol_bars, contract$development_start, contract$development_end, contract
    )
    train_n <- if (is.null(train_panel)) 0L else nrow(train_panel$x)
    development_n <- if (is.null(development_panel)) 0L else nrow(development_panel$x)
    ledger$train_anchor_count[[ledger_i]] <- train_n
    ledger$development_anchor_count[[ledger_i]] <- development_n
    enough <- train_n >= contract$minimum_period_anchors &
      development_n >= contract$minimum_period_anchors
    ledger$analysis_eligible[[ledger_i]] <- enough
    if (!enough) {
      ledger$eligibility_reason[[ledger_i]] <- "insufficient_common_period_anchors"
      next
    }
    surface <- g5_mom014_surface(train_panel, contract)
    if (nrow(surface) != 28L || anyDuplicated(surface$cell_id)) {
      g5_mom014_stop(paste("Incomplete TRAIN surface for", registry_row$analysis_id))
    }
    tagged_surface <- g5_mom014_bind_tag(surface, registry_row)
    train_surfaces[[registry_row$analysis_id]] <- tagged_surface
    nominee <- g5_mom014_nominate(surface)
    if (!nrow(nominee)) {
      ledger$train_nomination_status[[ledger_i]] <- "NO_POSITIVE_TRAIN_CELL"
      next
    }
    ledger$train_nomination_status[[ledger_i]] <- "POSITIVE_TRAIN_CELL_NOMINATED"
    nominee <- g5_mom014_bind_tag(nominee, registry_row)
    nominees[[registry_row$analysis_id]] <- nominee
    pairs <- g5_mom014_cell_pairs(
      development_panel,
      nominee$lookback_sessions[[1L]], nominee$target_sessions[[1L]], contract
    )
    stats <- g5_mom014_cell_statistics(
      pairs$predictor_log_return, pairs$target_log_return,
      nominee$lookback_sessions[[1L]], nominee$target_sessions[[1L]]
    )
    shift <- g5_mom014_fixed_shift_test(pairs, contract)
    bootstrap <- g5_mom014_stationary_beta(
      pairs, contract$bootstrap_seed_base + registry_row$order[[1L]], contract
    )
    dev_row <- cbind(
      nominee[, c("analysis_id", "symbol", "category", "analysis_stratum", "cell_id", "selection_rule"), drop = FALSE],
      is_spy_reference = registry_row$is_spy_reference,
      train_correlation = nominee$correlation,
      stats,
      shift$summary,
      bootstrap
    )
    development[[registry_row$analysis_id]] <- dev_row
    shift_distributions[[registry_row$analysis_id]] <- cbind(
      analysis_id = registry_row$analysis_id,
      shift$distribution
    )
    stored_pairs[[registry_row$analysis_id]] <- pairs
    stored_panels[[registry_row$analysis_id]] <- development_panel
    stored_surfaces[[registry_row$analysis_id]] <- surface
  }

  ledger$train_anchor_count[is.na(ledger$train_anchor_count)] <- 0L
  ledger$development_anchor_count[is.na(ledger$development_anchor_count)] <- 0L
  ledger$analysis_eligible[is.na(ledger$analysis_eligible)] <- FALSE
  ledger$train_nomination_status[is.na(ledger$train_nomination_status)] <- "NOT_TESTED_INELIGIBLE"
  train_surface <- if (length(train_surfaces)) do.call(rbind, train_surfaces) else data.frame()
  nominee_table <- if (length(nominees)) do.call(rbind, nominees) else data.frame()
  development_table <- if (length(development)) do.call(rbind, development) else data.frame()
  shift_table <- if (length(shift_distributions)) do.call(rbind, shift_distributions) else data.frame()
  rownames(train_surface) <- rownames(nominee_table) <- rownames(development_table) <- rownames(shift_table) <- NULL

  development_table <- g5_mom014_apply_fdr(development_table, contract)
  candidates <- if (nrow(development_table)) {
    development_table[development_table$is_development_candidate, , drop = FALSE]
  } else {
    development_table
  }
  candidate_pairs <- candidate_quintiles <- candidate_years <- candidate_phases <- candidate_neighbors <- list()
  if (nrow(candidates)) {
    for (candidate_i in seq_len(nrow(candidates))) {
      id <- candidates$analysis_id[[candidate_i]]
      tag <- registry[registry$analysis_id == id, , drop = FALSE]
      pairs <- stored_pairs[[id]]
      candidate_pairs[[id]] <- g5_mom014_bind_tag(pairs, tag)
      candidate_quintiles[[id]] <- g5_mom014_bind_tag(g5_mom014_quintiles(pairs), tag)
      candidate_years[[id]] <- g5_mom014_bind_tag(g5_mom014_years(pairs), tag)
      candidate_phases[[id]] <- g5_mom014_bind_tag(g5_mom014_phases(pairs), tag)
      candidate_neighbors[[id]] <- g5_mom014_bind_tag(
        g5_mom014_neighbors(stored_surfaces[[id]], nominees[[id]], contract), tag
      )
    }
  }
  bind_or_empty <- function(x) if (length(x)) do.call(rbind, x) else data.frame()
  status <- if (nrow(candidates)) {
    "DEVELOPMENT_FDR_TRANSPORT_CANDIDATES_FROZEN_CONFIRMATION_CLOSED"
  } else {
    "STOP_LIT_MOM_01_4_NO_FDR_CONTROLLED_TRANSPORT"
  }
  list(
    contract = contract,
    registry = registry,
    ledger = ledger,
    train_surface = train_surface,
    train_nominees = nominee_table,
    development = development_table,
    shift_distributions = shift_table,
    candidates = candidates,
    category_summary = g5_mom014_category_summary(ledger, development_table),
    candidate_pairs = bind_or_empty(candidate_pairs),
    candidate_quintiles = bind_or_empty(candidate_quintiles),
    candidate_years = bind_or_empty(candidate_years),
    candidate_phases = bind_or_empty(candidate_phases),
    candidate_neighbors = bind_or_empty(candidate_neighbors),
    overall_status = status,
    confirmation_opened = FALSE
  )
}
