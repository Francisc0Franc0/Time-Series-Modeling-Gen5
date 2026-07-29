source(testthat::test_path("..", "..", "R", "gen5_lit_mr_02_1_bollinger_poc.R"))
source(testthat::test_path("..", "..", "R", "gen5_lit_mr_02_1_pair_panel.R"))
source(testthat::test_path("..", "..", "R", "gen5_lit_mr_02_2_relaxed_pair_poc.R"))

mr022_fake_result <- function() {
  directions <- rep(c(1L, -1L), each = 12L)
  list(
    contract = g5_mr02_contract(),
    train_indicators = data.frame(
      session_date = seq(as.Date("2016-01-04"), by = "day", length.out = 50L),
      z_score = 1,
      beta = 1
    ),
    train_trades = data.frame(
      completed = TRUE,
      direction = directions,
      primary_net_additive_return = rep(0.02, 24L)
    ),
    train_bootstrap = list(
      draws = data.frame(mean_primary_net_trade_return = rep(0.01, 100L))
    ),
    train_random = list(p90 = 0.005),
    train_convergence_bootstrap = list(
      summary = data.frame(correlation = -0.20),
      draws = data.frame(correlation = rep(-0.10, 100L))
    ),
    train_integrity = data.frame(status = rep("PASS", 12L)),
    train_years = data.frame(
      calendar_year = 2016:2020,
      primary_net_return = c(0.1, -0.1, 0.1, -0.1, 0.1)
    ),
    train_gates = data.frame(status = rep("PASS", 8L))
  )
}

testthat::test_that("02.2 registries are finite, frozen, and non-overlapping", {
  retro <- g5_mr022_retrospective_registry()
  fresh <- g5_mr022_fresh_registry()
  testthat::expect_equal(nrow(retro), 44L)
  testthat::expect_equal(nrow(fresh), 20L)
  testthat::expect_equal(as.integer(table(fresh$candidate_category)), rep(4L, 5L))
  retro_keys <- vapply(seq_len(nrow(retro)), function(i) {
    paste(sort(c(retro$symbol_y[[i]], retro$symbol_x[[i]])), collapse = "|")
  }, character(1))
  fresh_keys <- vapply(seq_len(nrow(fresh)), function(i) {
    paste(sort(c(fresh$symbol_y[[i]], fresh$symbol_x[[i]])), collapse = "|")
  }, character(1))
  testthat::expect_length(intersect(retro_keys, fresh_keys), 0L)
})

testthat::test_that("02.2 fresh registry mutation fails loudly", {
  fresh <- g5_mr022_fresh_registry()
  fresh$symbol_x[[1L]] <- "SPY"
  testthat::expect_error(
    g5_mr022_validate_registry(fresh, "FRESH_ATLAS_01"),
    "frozen FRESH_ATLAS_01 pair registry changed"
  )
})

testthat::test_that("02.2 mandatory gates use q10 and q90 while diagnostics report", {
  result <- mr022_fake_result()
  gates <- g5_mr022_relaxed_gates(result)
  mandatory <- gates[gates$gate_role == "MANDATORY", , drop = FALSE]
  diagnostics <- gates[gates$gate_role == "DIAGNOSTIC", , drop = FALSE]
  testthat::expect_true(all(mandatory$status == "PASS"))
  testthat::expect_true(all(diagnostics$status == "REPORTED"))
  result$train_bootstrap$draws$mean_primary_net_trade_return[1:11] <- -10
  gates <- g5_mr022_relaxed_gates(result)
  testthat::expect_equal(gates$status[gates$gate_id == "R4"], "FAIL")
})

testthat::test_that("02.2 source contains no implicit current-date call", {
  path <- testthat::test_path(
    "..", "..", "R", "gen5_lit_mr_02_2_relaxed_pair_poc.R"
  )
  code <- paste(readLines(path, warn = FALSE), collapse = "\n")
  testthat::expect_false(grepl("Sys.Date\\(", code))
})
