library(testthat)

repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_01_4_multi_market_predictor_atlas.R"))
source(file.path(repo_root, "literature_studies", "R", "gen5_lit_mom_01_5_path_quality_forecast_comparison.R"))
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_intraday_alpaca_30min.R"))
source(file.path(
  repo_root, "literature_studies", "R", "gen5_lit_imom_01_3_same_slot_relative_momentum.R"
))

imom013_registry <- function() read.csv(
  file.path(repo_root, "operator_hypothesis_lab", "registries", "gen5_intraday_momentum_poc_registry.csv"),
  stringsAsFactors = FALSE
)

imom013_synthetic_panel <- function(train_sessions = 120L, development_sessions = 80L,
                                    beta = 0.35, seed = 1L) {
  set.seed(seed)
  total <- train_sessions + development_sessions
  source <- matrix(stats::rnorm(total * 13L, sd = 0.012), nrow = total)
  day <- rowSums(source) + stats::rnorm(total, sd = 0.004)
  noise <- matrix(stats::rnorm(total * 13L, sd = 0.010), nrow = total)
  target <- beta * source + 0.04 * day + noise
  dates <- as.Date("2018-01-02") + seq_len(total) - 1L
  rows <- lapply(seq_len(total), function(i) {
    out <- data.frame(
      target_session = rep(dates[[i]], 13L),
      previous_session = rep(dates[[i]] - 1L, 13L),
      analysis_split = if (i <= train_sessions) "TRAIN" else "DEVELOPMENT",
      target_slot = 1:13,
      target_relative_return = target[i, ],
      prior_session_relative_return = rep(day[[i]], 13L),
      stringsAsFactors = FALSE
    )
    for (slot in 1:13) out[[sprintf("source_%02d", slot)]] <- source[i, slot]
    out
  })
  do.call(rbind, rows)
}

imom013_synthetic_bars <- function(dates, slots_by_date) {
  registry <- g5_imom013_validate_registry(imom013_registry())
  rows <- list(); k <- 0L
  for (date_i in seq_along(dates)) {
    slots <- slots_by_date[[date_i]]
    for (symbol_i in seq_len(nrow(registry))) {
      symbol <- registry$symbol[[symbol_i]]
      for (slot in slots) {
        k <- k + 1L
        price <- 100 + symbol_i / 10 + date_i + slot / 100
        rows[[k]] <- data.frame(
          symbol = symbol,
          timestamp_utc = as.POSIXct(paste(dates[[date_i]], "14:30:00"), tz = "UTC") + (slot - 1L) * 1800,
          session_date = dates[[date_i]], bar_time_et = sprintf("%02d:%02d", 9L + (30L * (slot - 1L)) %/% 60L,
            30L * (slot - 1L) %% 60L),
          bar_slot = slot, open = price, high = price * 1.002, low = price * 0.998,
          close = price * (1 + (symbol_i - 13) * 1e-6 + slot * 1e-6), volume = 1000,
          provider = "alpaca", feed = "sip", timeframe = "30Min", adjustment = "all",
          as_of_timestamp = "2026-08-13 17:30:00 America/New_York",
          stringsAsFactors = FALSE
        )
      }
    }
  }
  do.call(rbind, rows)
}

test_that("frozen contract exposes one lag and twelve wrong-clock controls", {
  contract <- g5_imom013_contract()
  expect_equal(contract$literature_id, "LIT-IMOM-01.3")
  expect_equal(contract$benchmark_symbol, "SPY")
  expect_equal(contract$full_session_slots, 1:13)
  expect_equal(contract$placebo_offsets, 1:12)
  expect_equal(length(contract$model_ids), 15L)
  expect_equal(contract$bootstrap_expected_sessions, 20)
  expect_true(contract$query_end < contract$confirmation_start)
})

test_that("contract mutation fails loudly", {
  changed <- g5_imom013_contract()
  changed$panel_p <- 0.10
  expect_error(g5_imom013_validate_contract(changed), "Frozen contract changed")
})

test_that("registry creates one benchmark, 22 candidates, and three diagnostics", {
  registry <- g5_imom013_validate_registry(imom013_registry())
  expect_equal(nrow(registry), 26L)
  expect_equal(sum(registry$benchmark_only), 1L)
  expect_equal(sum(!registry$benchmark_only), 25L)
  expect_equal(sum(registry$candidate_fdr), 22L)
  expect_setequal(registry$symbol[!registry$benchmark_only & !registry$candidate_fdr], c("AMD", "TSLA", "QQQ"))
})

test_that("clock matrix is a full-rank 13-slot surface", {
  x <- g5_imom013_clock_matrix(1:13)
  expect_equal(dim(x), c(13L, 12L))
  expect_equal(qr(cbind(1, x))$rank, 13L)
  expect_error(g5_imom013_clock_matrix(c(1, 14)), "13-slot")
})

test_that("session calendar does not bridge exclusions or incomplete sessions", {
  dates <- as.Date(c("2018-05-01", "2018-05-02", "2018-05-03", "2018-05-04", "2018-05-07", "2018-05-08", "2018-05-09"))
  slots <- list(1:13, 1:13, 1:13, 1:13, 1:13, 1:7, 1:13)
  registry <- g5_imom013_validate_registry(imom013_registry())
  bars <- g5_imom013_prepare_bars(imom013_synthetic_bars(dates, slots), registry)
  calendar <- g5_imom013_session_calendar(bars, registry)
  expect_false(calendar$consecutive_pair_eligible[calendar$session_date == as.Date("2018-05-04")])
  expect_true(calendar$consecutive_pair_eligible[calendar$session_date == as.Date("2018-05-07")])
  expect_false(calendar$full_13_slot_panel[calendar$session_date == as.Date("2018-05-08")])
  expect_false(calendar$consecutive_pair_eligible[calendar$session_date == as.Date("2018-05-09")])
})

test_that("source alignment uses the matching and circularly displaced slots", {
  panel <- imom013_synthetic_panel(20L, 10L, beta = 0)
  moments <- g5_imom013_train_moments(panel[panel$analysis_split == "TRAIN", ])
  x <- g5_imom013_standardize_panel(panel, moments)
  same <- g5_imom013_source_vector(x, 0L)
  plus_one <- g5_imom013_source_vector(x, 1L)
  expect_equal(same[x$target_slot == 1L], x$source_z_01[x$target_slot == 1L])
  expect_equal(plus_one[x$target_slot == 1L], x$source_z_02[x$target_slot == 1L])
  expect_equal(plus_one[x$target_slot == 13L], x$source_z_01[x$target_slot == 13L])
})

test_that("same-slot synthetic process is recovered without selecting a slot", {
  fit <- g5_imom013_fit_asset(imom013_synthetic_panel(beta = 0.45, seed = 11L))
  coefficient <- fit$coefficients$coefficient[
    fit$coefficients$model_id == "M2_SAME" & fit$coefficients$feature == "same_slot"
  ]
  losses <- setNames(fit$metrics$development_scaled_loss, fit$metrics$model_id)
  expect_gt(coefficient, 0.25)
  expect_lt(losses[["M2_SAME"]], losses[["M1_DAY"]])
  expect_equal(unique(fit$metrics$development_sessions), 80L)
  expect_equal(nrow(fit$session_losses), 80L)
  expect_equal(unique(fit$coefficients$fit_rank[fit$coefficients$model_id == "M2_SAME"]), 15L)
})

test_that("null same-slot process does not manufacture a large coefficient", {
  fit <- g5_imom013_fit_asset(imom013_synthetic_panel(beta = 0, seed = 29L))
  coefficient <- fit$coefficients$coefficient[
    fit$coefficients$model_id == "M2_SAME" & fit$coefficients$feature == "same_slot"
  ]
  expect_lt(abs(coefficient), 0.12)
})

test_that("specificity inference recomputes the best placebo and is deterministic", {
  set.seed(5)
  x <- data.frame(S21 = rep(0.08, 100L) + stats::rnorm(100L, 0, 0.01))
  for (k in 1:12) x[[sprintf("W%02d", k)]] <- rep(0.01 + k / 1000, 100L) + stats::rnorm(100L, 0, 0.01)
  a <- g5_imom013_specificity_inference(x, 123L, 300L, 20)
  b <- g5_imom013_specificity_inference(x, 123L, 300L, 20)
  expect_equal(a, b)
  expect_gt(a$observed_mean_differential, 0)
  expect_equal(a$best_placebo_offset, unname(which.max(colMeans(x[sprintf("W%02d", 1:12)]))))
})

test_that("a stronger wrong-clock model falsifies clock specificity", {
  x <- data.frame(S21 = rep(0.05, 80L))
  for (k in 1:12) x[[sprintf("W%02d", k)]] <- rep(if (k == 7L) 0.08 else 0.01, 80L)
  out <- g5_imom013_specificity_inference(x, 123L, 100L, 20)
  expect_equal(out$best_placebo_offset, 7L)
  expect_lt(out$observed_mean_differential, 0)
})

test_that("FDR excludes diagnostic rows", {
  contract <- g5_imom013_contract()
  contrasts <- expand.grid(contrast_id = contract$contrast_ids, row = 1:3, stringsAsFactors = FALSE)
  contrasts$candidate_fdr <- contrasts$row != 3L
  contrasts$centered_null_upper_p <- rep(c(0.01, 0.04, 0.001), length(contract$contrast_ids))
  out <- g5_imom013_apply_fdr(contrasts)
  expect_true(all(is.na(out$bh_q_value[!out$candidate_fdr])))
  expect_true(all(is.finite(out$bh_q_value[out$candidate_fdr])))
})

test_that("asset candidate requires all three same-slot gates", {
  registry <- g5_imom013_validate_registry(imom013_registry())
  registry <- registry[registry$symbol %in% c("MSFT", "AMD"), ]
  make <- function(id, candidate) data.frame(
    analysis_id = id, contrast_id = g5_imom013_contract()$contrast_ids,
    observed_mean_differential = rep(0.1, 4L), ci_lower_90 = rep(0.02, 4L),
    bh_q_value = if (candidate) rep(0.05, 4L) else rep(NA_real_, 4L), stringsAsFactors = FALSE
  )
  contrasts <- rbind(make(registry$analysis_id[registry$symbol == "MSFT"], TRUE),
    make(registry$analysis_id[registry$symbol == "AMD"], FALSE))
  coefficients <- data.frame(
    analysis_id = registry$analysis_id, same_slot_coefficient = 0.2, stringsAsFactors = FALSE
  )
  out <- g5_imom013_decisions(contrasts, coefficients, registry)
  expect_true(out$is_same_slot_candidate[out$symbol == "MSFT"])
  expect_false(out$is_same_slot_candidate[out$symbol == "AMD"])
})

test_that("result vocabulary cannot imply strategy or confirmation authority", {
  contract <- g5_imom013_contract()
  forbidden <- c("trade", "position", "sharpe", "drawdown", "allocation", "leverage")
  expect_false(any(forbidden %in% names(contract)))
  expect_true(contract$query_end < contract$confirmation_start)
})
