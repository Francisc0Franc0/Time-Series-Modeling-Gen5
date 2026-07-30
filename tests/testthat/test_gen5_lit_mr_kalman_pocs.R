source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_kalman_core.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_04_1_kalman_pair_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mr_05_1_kalman_triplet_poc.R"
))

kf_sessions <- function(n = 520L) {
  dates <- seq(as.Date("2016-01-04"), by = "day", length.out = ceiling(n * 7 / 5) + 30L)
  dates <- dates[!as.POSIXlt(dates)$wday %in% c(0L, 6L)]
  head(dates, n)
}

kf_synthetic_bars <- function(n = 520L, triplet = FALSE) {
  set.seed(90210)
  dates <- kf_sessions(n)
  ewa <- 45 + cumsum(stats::rnorm(n, 0.02, 0.35))
  ige <- 30 + cumsum(stats::rnorm(n, 0.01, 0.28))
  deviation <- numeric(n)
  for (i in 2:n) {
    deviation[[i]] <- 0.65 * deviation[[i - 1L]] + stats::rnorm(1, 0, 0.35)
  }
  ewc <- if (triplet) {
    0.72 * ewa + 0.24 * ige + 4 + deviation
  } else {
    0.83 * ewa + 5 + deviation
  }
  series <- list(EWC = ewc, EWA = ewa)
  if (triplet) series$IGE <- ige
  do.call(rbind, lapply(names(series), function(symbol) {
    close <- series[[symbol]]
    data.frame(
      symbol = symbol,
      session_date = dates,
      open = close * (1 + stats::rnorm(n, 0, 0.0007)),
      high = close * 1.002,
      low = close * 0.998,
      close = close,
      volume = rep(1e6, n),
      stringsAsFactors = FALSE
    )
  }))
}

testthat::test_that("Kalman contracts freeze identities and sealed dates", {
  pair <- g5_mr04_contract()
  triplet <- g5_mr05_contract()
  testthat::expect_equal(pair$symbols, c("EWC", "EWA"))
  testthat::expect_equal(triplet$symbols, c("EWC", "EWA", "IGE"))
  testthat::expect_equal(pair$delta, 0.0001)
  testthat::expect_equal(pair$confirmation_start, as.Date("2024-01-01"))
  changed <- pair
  changed$entry_z <- 0.5
  testthat::expect_error(
    g5_mr04_validate_contract(changed),
    "Frozen LIT-MR-04.1 contract changed"
  )
})

testthat::test_that("one-step Kalman update uses the pre-update innovation", {
  panel <- g5_kf_common_panel(
    kf_synthetic_bars(),
    g5_mr04_contract()$symbols,
    g5_mr04_contract()$train_end
  )
  fit <- g5_kf_filter(panel, g5_mr04_contract())
  i <- g5_mr04_contract()$warmup_sessions + 1L
  h <- c(panel$close_2[[i]], 1)
  expected <- panel$close_1[[i]] -
    sum(h * as.numeric(fit$rows[i, c("prior_beta_1", "prior_intercept")]))
  post_residual <- panel$close_1[[i]] -
    sum(h * as.numeric(fit$rows[i, c("posterior_beta_1", "posterior_intercept")]))
  testthat::expect_equal(fit$rows$innovation[[i]], expected, tolerance = 1e-10)
  testthat::expect_lt(abs(post_residual), abs(expected))
  testthat::expect_gt(fit$rows$innovation_variance[[i]], 0)
})

testthat::test_that("pair replay is causal and gross normalized", {
  result <- g5_mr04_run_train(kf_synthetic_bars())
  active <- result$replay$target_state != 0L
  testthat::expect_true(result$structural_pass)
  testthat::expect_true(all(result$replay$signal_date < result$replay$execution_date))
  testthat::expect_true(all(
    result$replay$execution_date < result$replay$next_execution_date
  ))
  testthat::expect_true(all(
    abs(result$replay$gross_exposure[active] - 1) < 1e-10
  ))
  testthat::expect_true(all(result$rows$target_state[1:252] == 0L))
})

testthat::test_that("triplet extension uses one asymmetric mixed-sign vector", {
  result <- g5_mr05_run_train(kf_synthetic_bars(triplet = TRUE))
  active <- result$replay[result$replay$target_state != 0L, , drop = FALSE]
  testthat::expect_true(result$structural_pass)
  testthat::expect_gt(nrow(active), 0L)
  testthat::expect_true(all(abs(active$gross_exposure - 1) < 1e-10))
  weights <- as.matrix(active[c("weight_1", "weight_2", "weight_3")])
  testthat::expect_true(all(apply(weights, 1, function(x) {
    any(x > 0) && any(x < 0)
  })))
})

testthat::test_that("future bars fail the explicit query boundary", {
  bars <- kf_synthetic_bars()
  bars$session_date[[1L]] <- as.Date("2024-01-02")
  testthat::expect_error(
    g5_mr04_run_train(bars),
    "explicit date boundary"
  )
})

testthat::test_that("Kalman modules contain no implicit current-date call", {
  files <- c(
    "gen5_lit_mr_kalman_core.R",
    "gen5_lit_mr_04_1_kalman_pair_poc.R",
    "gen5_lit_mr_05_1_kalman_triplet_poc.R"
  )
  for (file in files) {
    code <- paste(readLines(testthat::test_path("..", "..", "R", file)), collapse = "\n")
    testthat::expect_false(grepl("Sys.Date\\(", code), info = file)
  }
})
