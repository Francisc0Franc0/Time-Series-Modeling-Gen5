# TRAIN-only target-structure audit engine for HYP-MOM-04.3A.
# Source hyp_mom_04_1_engine.R and hyp_mom_04_2_engine.R before this file.

h043a_stop <- function(message) stop(message, call. = FALSE)

h043a_target_dictionary <- function() {
  data.frame(
    target_id = c("UNIVERSE_RELATIVE", "SECTOR_RELATIVE", "SECTOR_BETA_RESIDUAL"),
    column = c("target_universe_relative", "target_sector_relative", "target_sector_beta_residual"),
    question = c(
      "Which stocks beat the eligible universe next quarter?",
      "Which stocks beat their same-sector peers next quarter?",
      "Which stocks beat what their sector and prior beta would imply?"
    ),
    role = c("REFERENCE", "PRIMARY_CHALLENGER", "DIAGNOSTIC_CHALLENGER"),
    stringsAsFactors = FALSE
  )
}

h043a_baseline_dictionary <- function() {
  data.frame(
    baseline_id = c(
      "HIGH_BETA", "LOW_VOLATILITY", "PRIOR_MOMENTUM",
      "PRIOR_SECTOR_LEADERSHIP", "WITHIN_SECTOR_MOMENTUM"
    ),
    column = c("beta126", "rv126", "momentum12_1", "sector_leadership126", "sector_relative126"),
    direction = c(1, -1, 1, 1, 1),
    plain_english = c(
      "Higher prior 126-session beta",
      "Lower prior 126-session realized volatility",
      "Higher prior twelve-to-one-month momentum",
      "Stronger prior 126-session sector return",
      "Stronger prior 126-session return versus sector peers"
    ),
    stringsAsFactors = FALSE
  )
}

h043a_contract <- function() {
  list(
    program_id = "HYP-MOM-04.3A",
    source_program_id = "HYP-MOM-04.2",
    source_run_id = "hyp_mom_04_2_feature_atlas_train_20260811",
    source_required_status = "STOP_TRAIN_GATES_FAILED_OOS_NOT_RUN",
    train_signal_quarters = paste0(rep(2017:2020, each = 4), "Q", rep(1:4, 4))[1:15],
    forbidden_start = as.Date("2021-01-01"),
    minimum_assets = 400L,
    minimum_assets_per_quarter = 20L,
    minimum_sector_members = 3L,
    target_ids = h043a_target_dictionary()$target_id,
    feature_names = h042_feature_dictionary()$feature,
    top_fraction = 0.25,
    winsor_probabilities = c(0.01, 0.99),
    tail_fraction = 0.01
  )
}

h043a_validate_contract <- function(contract = h043a_contract()) {
  frozen <- h043a_contract()
  if (!identical(names(contract), names(frozen))) h043a_stop("Frozen HYP-MOM-04.3A contract fields changed.")
  same <- vapply(names(frozen), function(name) identical(contract[[name]], frozen[[name]]), logical(1))
  if (!all(same)) h043a_stop(paste("Frozen HYP-MOM-04.3A contract changed:", paste(names(frozen)[!same], collapse = ", ")))
  contract
}

h043a_quantile_bin <- function(x, bins = 4L) {
  if (!length(x) || any(!is.finite(x))) h043a_stop("Quantile bins require finite values.")
  pmin(bins, pmax(1L, ceiling(rank(x, ties.method = "average") / length(x) * bins)))
}

h043a_spearman <- function(x, y) {
  if (length(x) < 3L || length(y) != length(x) || stats::sd(x) == 0 || stats::sd(y) == 0) return(NA_real_)
  suppressWarnings(stats::cor(x, y, method = "spearman"))
}

h043a_r2 <- function(y, design) {
  fit <- stats::lm.fit(design, y)
  residual <- fit$residuals
  total <- sum((y - mean(y))^2)
  if (!is.finite(total) || total == 0) return(0)
  max(0, min(1, 1 - sum(residual^2) / total))
}

h043a_build_targets <- function(panel, contract = h043a_contract()) {
  h043a_validate_contract(contract)
  required <- c(
    "row_id", "symbol", "sector", "signal_quarter", "signal_date", "entry_date", "exit_date",
    "target_return", "target_relative_return", "beta126", "rv126", "momentum12_1",
    "return126_raw", "sector_relative126", contract$feature_names
  )
  missing <- setdiff(required, names(panel))
  if (length(missing)) h043a_stop(paste("Retained H04.2 panel is missing:", paste(missing, collapse = ", ")))
  panel <- panel[order(match(panel$signal_quarter, contract$train_signal_quarters), panel$symbol), , drop = FALSE]
  if (anyDuplicated(panel$row_id)) h043a_stop("Retained H04.2 panel has duplicate row_id values.")
  panel$signal_date <- as.Date(panel$signal_date)
  panel$entry_date <- as.Date(panel$entry_date)
  panel$exit_date <- as.Date(panel$exit_date)
  panel$sector_leadership126 <- panel$return126_raw - panel$sector_relative126
  panel$target_universe_relative <- panel$target_return - ave(panel$target_return, panel$signal_quarter, FUN = mean)
  sector_key <- interaction(panel$signal_quarter, panel$sector, drop = TRUE)
  panel$target_sector_relative <- panel$target_return - ave(panel$target_return, sector_key, FUN = mean)
  panel$target_sector_beta_residual <- NA_real_
  for (quarter in contract$train_signal_quarters) {
    rows <- which(panel$signal_quarter == quarter)
    x <- panel[rows, , drop = FALSE]
    design <- stats::model.matrix(~ sector + beta126, data = x)
    fit <- stats::lm.fit(design, x$target_return)
    panel$target_sector_beta_residual[rows] <- fit$residuals
  }
  panel
}

h043a_integrity <- function(panel, source_status, source_integrity, contract = h043a_contract()) {
  dictionary <- h043a_target_dictionary()
  target_columns <- dictionary$column
  sector_counts <- table(interaction(panel$signal_quarter, panel$sector, drop = TRUE))
  universe_center <- max(abs(tapply(panel$target_universe_relative, panel$signal_quarter, mean)))
  sector_center <- max(abs(tapply(panel$target_sector_relative,
                                  interaction(panel$signal_quarter, panel$sector, drop = TRUE), mean)))
  residual_center <- max(abs(tapply(panel$target_sector_beta_residual,
                                    interaction(panel$signal_quarter, panel$sector, drop = TRUE), mean)))
  dates <- c(panel$signal_date, panel$entry_date, panel$exit_date)
  data.frame(
    check_id = c(
      "SOURCE_STATUS", "SOURCE_INTEGRITY", "ALL_15_TRAIN_QUARTERS", "AT_LEAST_400_IDENTITIES",
      "MINIMUM_ASSETS_PER_QUARTER", "TARGETS_AND_INPUTS_FINITE", "MINIMUM_SECTOR_MEMBERS",
      "TARGET_CENTERING", "CHRONOLOGY", "NO_OOS_OBSERVATIONS", "REFERENCE_TARGET_REPRODUCED"
    ),
    passed = c(
      identical(source_status, contract$source_required_status),
      nrow(source_integrity) > 0L && all(source_integrity$passed),
      identical(unique(panel$signal_quarter), contract$train_signal_quarters),
      length(unique(panel$symbol)) >= contract$minimum_assets,
      min(table(panel$signal_quarter)) >= contract$minimum_assets_per_quarter,
      all(is.finite(as.matrix(panel[c(target_columns, "target_return", "beta126")]))),
      min(sector_counts) >= contract$minimum_sector_members,
      max(universe_center, sector_center, residual_center) < 1e-10,
      all(panel$signal_date < panel$entry_date & panel$entry_date < panel$exit_date),
      all(dates < contract$forbidden_start),
      max(abs(panel$target_universe_relative - panel$target_relative_return)) < 1e-12
    ),
    estimate = c(
      as.character(source_status), as.character(all(source_integrity$passed)),
      length(unique(panel$signal_quarter)), length(unique(panel$symbol)), min(table(panel$signal_quarter)),
      as.character(all(is.finite(as.matrix(panel[c(target_columns, "target_return", "beta126")])))),
      min(sector_counts), max(universe_center, sector_center, residual_center),
      as.character(all(panel$signal_date < panel$entry_date & panel$entry_date < panel$exit_date)),
      as.character(max(dates)), max(abs(panel$target_universe_relative - panel$target_relative_return))
    ),
    threshold = c(
      contract$source_required_status, "all source checks pass", "15 ordered quarters", ">=400",
      ">=20", "all finite", ">=3", "max absolute group mean <1e-10",
      "signal < entry < exit", "all dates before 2021-01-01", "max absolute difference <1e-12"
    ),
    stringsAsFactors = FALSE
  )
}

h043a_target_long <- function(panel) {
  dictionary <- h043a_target_dictionary()
  do.call(rbind, lapply(seq_len(nrow(dictionary)), function(i) {
    data.frame(
      row_id = panel$row_id, symbol = panel$symbol, sector = panel$sector,
      signal_quarter = panel$signal_quarter, target_id = dictionary$target_id[[i]],
      target_value = panel[[dictionary$column[[i]]]], stringsAsFactors = FALSE
    )
  }))
}

h043a_scale_diagnostics <- function(panel, contract = h043a_contract()) {
  dictionary <- h043a_target_dictionary()
  rows <- list()
  k <- 0L
  for (quarter in contract$train_signal_quarters) {
    x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
    for (i in seq_len(nrow(dictionary))) {
      y <- x[[dictionary$column[[i]]]]
      q <- stats::quantile(y, c(0.01, 0.10, 0.25, 0.75, 0.90, 0.99), names = FALSE)
      tail_n <- max(1L, ceiling(length(y) * contract$tail_fraction))
      tail_share <- sum(sort(abs(y), decreasing = TRUE)[seq_len(tail_n)]) / sum(abs(y))
      winsor <- pmax(q[[1L]], pmin(q[[6L]], y))
      k <- k + 1L
      rows[[k]] <- data.frame(
        signal_quarter = quarter, target_id = dictionary$target_id[[i]], n = length(y),
        mean = mean(y), sd = stats::sd(y), iqr = stats::IQR(y), mad = stats::mad(y, constant = 1),
        p90_minus_p10 = q[[5L]] - q[[2L]], positive_fraction = mean(y > 0),
        top_1pct_absolute_mass_share = tail_share,
        winsorized_to_raw_sd = stats::sd(winsor) / stats::sd(y), stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

h043a_target_agreement <- function(panel, contract = h043a_contract()) {
  dictionary <- h043a_target_dictionary()
  pairs <- utils::combn(seq_len(nrow(dictionary)), 2L)
  rows <- list()
  k <- 0L
  for (quarter in contract$train_signal_quarters) {
    x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
    for (j in seq_len(ncol(pairs))) {
      a <- pairs[1L, j]; b <- pairs[2L, j]
      ya <- x[[dictionary$column[[a]]]]; yb <- x[[dictionary$column[[b]]]]
      top_a <- x$row_id[h043a_quantile_bin(ya, 4L) == 4L]
      top_b <- x$row_id[h043a_quantile_bin(yb, 4L) == 4L]
      k <- k + 1L
      rows[[k]] <- data.frame(
        signal_quarter = quarter, target_a = dictionary$target_id[[a]], target_b = dictionary$target_id[[b]],
        rank_correlation = h043a_spearman(ya, yb),
        top_quartile_jaccard = length(intersect(top_a, top_b)) / length(union(top_a, top_b)),
        sign_agreement = mean(sign(ya) == sign(yb)), stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

h043a_return_decomposition <- function(panel, contract = h043a_contract()) {
  do.call(rbind, lapply(contract$train_signal_quarters, function(quarter) {
    x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
    y <- x$target_return
    sector <- stats::model.matrix(~ sector, data = x)
    beta <- cbind(intercept = 1, beta126 = x$beta126)
    full <- stats::model.matrix(~ sector + beta126, data = x)
    sector_r2 <- h043a_r2(y, sector)
    beta_r2 <- h043a_r2(y, beta)
    full_r2 <- h043a_r2(y, full)
    data.frame(
      signal_quarter = quarter, sector_r2 = sector_r2, beta_r2 = beta_r2,
      sector_beta_r2 = full_r2, incremental_beta_after_sector_r2 = full_r2 - sector_r2,
      stringsAsFactors = FALSE
    )
  }))
}

h043a_sector_concentration <- function(panel, contract = h043a_contract()) {
  dictionary <- h043a_target_dictionary()
  rows <- list(); k <- 0L
  for (quarter in contract$train_signal_quarters) {
    x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
    for (i in seq_len(nrow(dictionary))) {
      y <- x[[dictionary$column[[i]]]]
      selected <- x[h043a_quantile_bin(y, 4L) == 4L, , drop = FALSE]
      shares <- prop.table(table(selected$sector))
      k <- k + 1L
      rows[[k]] <- data.frame(
        signal_quarter = quarter, target_id = dictionary$target_id[[i]], selected_n = nrow(selected),
        sector_count = length(shares), max_sector_share = max(shares), sector_hhi = sum(shares^2),
        leading_sector = names(shares)[which.max(shares)], stringsAsFactors = FALSE
      )
    }
  }
  do.call(rbind, rows)
}

h043a_baseline_ic <- function(panel, contract = h043a_contract()) {
  baselines <- h043a_baseline_dictionary()
  targets <- h043a_target_dictionary()
  rows <- list(); k <- 0L
  for (quarter in contract$train_signal_quarters) {
    x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
    for (b in seq_len(nrow(baselines))) {
      score <- baselines$direction[[b]] * x[[baselines$column[[b]]]]
      for (t in seq_len(nrow(targets))) {
        k <- k + 1L
        rows[[k]] <- data.frame(
          signal_quarter = quarter, baseline_id = baselines$baseline_id[[b]],
          target_id = targets$target_id[[t]], rank_ic = h043a_spearman(score, x[[targets$column[[t]]]]),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

h043a_feature_ic <- function(panel, contract = h043a_contract()) {
  targets <- h043a_target_dictionary()
  rows <- list(); k <- 0L
  for (quarter in contract$train_signal_quarters) {
    x <- panel[panel$signal_quarter == quarter, , drop = FALSE]
    for (feature in contract$feature_names) {
      for (t in seq_len(nrow(targets))) {
        k <- k + 1L
        rows[[k]] <- data.frame(
          signal_quarter = quarter, feature = feature,
          family = h042_feature_dictionary()$family[match(feature, h042_feature_dictionary()$feature)],
          target_id = targets$target_id[[t]], rank_ic = h043a_spearman(x[[feature]], x[[targets$column[[t]]]]),
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

h043a_summarize_ic <- function(ic, id_column) {
  keys <- unique(ic[c(id_column, "target_id")])
  do.call(rbind, lapply(seq_len(nrow(keys)), function(i) {
    keep <- ic[[id_column]] == keys[[id_column]][[i]] & ic$target_id == keys$target_id[[i]]
    values <- ic$rank_ic[keep]
    data.frame(
      item = keys[[id_column]][[i]], target_id = keys$target_id[[i]],
      mean_rank_ic = mean(values), median_rank_ic = stats::median(values),
      sd_rank_ic = stats::sd(values), positive_quarters = sum(values > 0),
      positive_fraction = mean(values > 0), stringsAsFactors = FALSE
    )
  }))
}

h043a_run_audit <- function(panel, source_status, source_integrity, contract = h043a_contract()) {
  panel <- h043a_build_targets(panel, contract)
  integrity <- h043a_integrity(panel, source_status, source_integrity, contract)
  if (!all(integrity$passed)) h043a_stop("HYP-MOM-04.3A integrity checks failed before interpretation.")
  scale <- h043a_scale_diagnostics(panel, contract)
  agreement <- h043a_target_agreement(panel, contract)
  decomposition <- h043a_return_decomposition(panel, contract)
  concentration <- h043a_sector_concentration(panel, contract)
  baseline_ic <- h043a_baseline_ic(panel, contract)
  feature_ic <- h043a_feature_ic(panel, contract)
  list(
    panel = panel, integrity = integrity, scale = scale, agreement = agreement,
    decomposition = decomposition, concentration = concentration,
    baseline_ic = baseline_ic, baseline_summary = h043a_summarize_ic(baseline_ic, "baseline_id"),
    feature_ic = feature_ic, feature_summary = h043a_summarize_ic(feature_ic, "feature")
  )
}
