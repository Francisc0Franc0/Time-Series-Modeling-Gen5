library(testthat)

repo_root <- normalizePath(file.path(testthat::test_path(), "..", "..", ".."), winslash = "/", mustWork = TRUE)
source(file.path(repo_root, "operator_hypothesis_lab", "R", "hyp_mom_05_2_triple_sma_grid_wfa.R"))

h052_fixture <- function(n = 900L) {
  close <- 100 + seq_len(n) * 0.03 + 6 * sin(seq_len(n) / 17)
  data.frame(symbol = "TEST", session_date = as.Date("2019-01-01") + seq_len(n) - 1L,
             open = close, high = close * 1.01, low = close * .99, close = close,
             volume = 1000, stringsAsFactors = FALSE)
}

test_that("contract, grid, blocks, and folds are frozen", {
  contract <- h052_validate_contract()
  grid <- h052_grid(contract)
  expect_equal(nrow(grid), 27L)
  expect_true(all(grid$fast < grid$medium & grid$medium < grid$slow))
  expect_equal(h052_blocks()$block_id, c("2021H1", "2021H2", "2022H1", "2022H2", "2023H1", "2023H2"))
  folds <- h052_folds()
  expect_equal(length(folds), 4L)
  expect_equal(folds[[1L]]$train_blocks, c("2021H1", "2021H2"))
  expect_equal(folds[[4L]]$test_block, "2023H2")
  changed <- contract; changed$fast_grid <- c(5L, 10L)
  expect_error(h052_validate_contract(changed), "Frozen contract changed")
})

test_that("state is causal and rejects candidates outside the grid", {
  bars <- h052_fixture()
  candidate <- h052_grid()[1L, ]
  state <- h052_state(bars, candidate)
  expect_true(all(is.na(state$sma_slow[1:(candidate$slow - 1L)])))
  expect_equal(state$sma_slow[[candidate$slow]], mean(bars$close[1:candidate$slow]))
  bad <- candidate; bad$fast <- 11L
  expect_error(h052_state(bars, bad), "do not match")
})

test_that("schedule starts cash, executes next open, and ends cash", {
  candidate <- h052_grid()[h052_grid()$candidate_id == "F010_M030_S060", ]
  state <- h052_state(h052_fixture(), candidate)
  schedule <- h052_schedule(state, as.Date("2021-01-04"), as.Date("2021-06-30"), "H052")
  expect_false(schedule$target_long[[1L]])
  expect_false(tail(schedule$target_long, 1L))
  entries <- which(schedule$target_long & !c(FALSE, head(schedule$target_long, -1L)))
  if (length(entries)) expect_true(all(schedule$session_date[entries] > schedule$signal_date[entries]))
})

test_that("fixed-quantity leverage and costs behave monotonically on a rising trade", {
  state <- h052_state(h052_fixture(), h052_grid()[1L, ])
  idx <- which(state$session_date >= as.Date("2021-01-04") & state$session_date <= as.Date("2021-06-30"))
  schedule <- data.frame(row_index = idx, session_date = state$session_date[idx], signal_date = state$session_date[idx - 1L],
                         policy = "H052", target_long = c(TRUE, rep(TRUE, length(idx) - 2L), FALSE),
                         transition_reason = c("ORDER_ACTIVATION", rep("HOLD_LONG", length(idx) - 2L), "BOUNDARY_EXIT"))
  gross <- h052_replay(state, schedule, 1, 0, 0)
  net <- h052_replay(state, schedule, 1, 10, 0)
  levered <- h052_replay(state, schedule, 1.8, 5, .06)
  expect_lt(net$summary$total_return, gross$summary$total_return)
  expect_equal(net$summary$turnover_events, 2L)
  expect_gt(levered$summary$total_financing_cost, 0)
  expect_false(tail(levered$path$in_position_after_open, 1L))
})

test_that("vectorized 1x training replay equals the full ledger engine", {
  state <- h052_state(h052_fixture(), h052_grid()[1L, ])
  schedule <- h052_schedule(state, as.Date("2021-01-04"), as.Date("2021-06-30"), "H052")
  full <- h052_replay(state, schedule, 1, 5, .06)$summary
  fast <- h052_replay_fast_1x(state, schedule, 5)
  expect_equal(fast$total_return, full$total_return, tolerance = 1e-12)
  expect_equal(fast$maximum_drawdown, full$maximum_drawdown, tolerance = 1e-12)
  expect_equal(fast$sharpe, full$sharpe, tolerance = 1e-12)
  expect_equal(fast$trade_count, full$trade_count)
  expect_equal(fast$activation_entries, full$activation_entries)
  expect_equal(fast$reclaim_entries, full$reclaim_entries)
})

test_that("selection uses the one-standard-error plateau and turnover tie-break", {
  grid <- h052_grid()
  candidates <- grid$candidate_id[1:3]
  rows <- list(); k <- 0L
  for (block in c("2021H1", "2021H2")) for (candidate in candidates) for (symbol in c("A", "B")) {
    base <- match(candidate, candidates)
    for (policy in c("H052", "SMA_MEDIUM_ONLY", "ORDERED_STACK_ONLY")) {
      k <- k + 1L
      value <- if (policy == "H052") c(.03, .029, .02)[base] else .005
      rows[[k]] <- data.frame(candidate_id = candidate, block_id = block, symbol = symbol, policy = policy,
                              leverage = 1, total_return = value, sharpe = value * 10,
                              maximum_drawdown = -.1 + value, trade_count = c(9, 3, 5)[base])
    }
  }
  metrics <- do.call(rbind, rows)
  score <- h052_block_scorecard(metrics)
  fold <- list(fold = 1L, train_blocks = c("2021H1", "2021H2"), test_block = "2022H1")
  selected <- h052_select_fold(score, grid, fold)
  expect_equal(sum(selected$selected), 1L)
  expect_true(selected$candidate_id[selected$selected] %in% candidates)
  expect_gte(unique(selected$plateau_size), 1L)
})

test_that("sealed observations and circular controls are deterministic", {
  bars <- h052_fixture(); bars$session_date[[nrow(bars)]] <- as.Date("2024-01-02")
  expect_error(h052_validate_bars(bars), "Confirmation observations")
  open <- seq(100, 120, length.out = 40); target <- c(rep(FALSE, 5), rep(TRUE, 12), rep(FALSE, 23))
  a <- h052_circular_controls(open, target, 1, seed_offset = 7L)
  b <- h052_circular_controls(open, target, 1, seed_offset = 7L)
  expect_equal(a, b)
  expect_length(a, h052_contract()$random_simulations)
})

test_that("fold controls compound by asset, leverage, and simulation", {
  x <- data.frame(instance_id = c("A", "A", "A", "A"), symbol = "AAA", leverage = 1,
                  simulation_id = c(1L, 2L, 1L, 2L), fold_return = c(.10, .20, -.05, .10))
  out <- h052_compound_fold_controls(x)
  expect_equal(out$total_return[out$simulation_id == 1L], (1.10 * .95) - 1)
  expect_equal(out$total_return[out$simulation_id == 2L], (1.20 * 1.10) - 1)
  expect_error(h052_compound_fold_controls(x[, setdiff(names(x), "symbol")]), "lack compounding columns")
})
