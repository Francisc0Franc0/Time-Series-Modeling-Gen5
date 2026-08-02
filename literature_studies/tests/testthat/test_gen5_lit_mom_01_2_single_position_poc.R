source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_1_interday_momentum_poc.R"
))
source(testthat::test_path(
  "..", "..", "R", "gen5_lit_mom_01_2_single_position_poc.R"
))

mom012_fixture <- function(n = 900L) {
  dates <- seq.Date(as.Date("2015-01-02"), by = "day", length.out = n * 2L)
  dates <- dates[as.POSIXlt(dates)$wday %in% 1:5][seq_len(n)]
  index <- seq_len(n)
  close <- 80 * exp(0.00015 * index + 0.025 * sin(index / 18))
  open <- close * (1 + 0.0015 * cos(index / 11))
  data.frame(
    symbol = "SHY",
    session_date = dates,
    open = open,
    high = pmax(open, close) * 1.001,
    low = pmin(open, close) * 0.999,
    close = close,
    volume = 1e6,
    adjusted = TRUE,
    timeframe = "1D",
    stringsAsFactors = FALSE
  )
}

testthat::test_that("01.2 contract is immutable and explicitly retrospective", {
  contract <- g5_mom012_contract()
  testthat::expect_identical(
    contract$evidence_label,
    "RETROSPECTIVE_EXPLORATION"
  )
  testthat::expect_false(contract$allow_pyramiding)
  testthat::expect_false(contract$rebalance_within_trade)
  testthat::expect_identical(contract$position_scope, "LONG_ONLY")
  testthat::expect_equal(contract$stress_borrow_bps_annual, 0)
  changed <- contract
  changed$primary_cost_bps <- 0
  testthat::expect_error(
    g5_mom012_validate_contract(changed),
    "Frozen LIT-MOM-01.2 contract changed"
  )
})

testthat::test_that("01.2 allows only the frozen stock-atlas symbol substitution", {
  replication <- g5_mom012_replication_contract("MSFT")
  testthat::expect_identical(replication$symbol, "MSFT")
  testthat::expect_identical(
    attr(replication, "g5_mom012_replication_batch"),
    "STOCK_ATLAS_01_RETROSPECTIVE"
  )
  testthat::expect_identical(
    g5_mom012_parent_contract(replication)$symbol,
    "MSFT"
  )
  testthat::expect_error(g5_mom012_replication_contract("msft"), "uppercase")
})

testthat::test_that("three inference views include STEP_L and all phases", {
  bars <- mom012_fixture()
  views <- g5_mom012_inference_views(
    bars,
    as.Date("2016-01-04"),
    as.Date("2018-01-31"),
    lookback_sessions = 60L,
    holding_sessions = 5L
  )
  testthat::expect_identical(
    views$summary$sampling_id,
    c("CHAN_MIN_STEP", "STEP_L", "STRICT_L_PLUS_H")
  )
  testthat::expect_equal(views$summary$step_sessions, c(5L, 60L, 65L))
  testthat::expect_equal(nrow(views$step_l_phase_offsets), 60L)
  testthat::expect_equal(
    views$step_l_phase_offsets$phase_offset,
    0:59
  )
})

testthat::test_that("single-position schedule is causal and nonoverlapping", {
  bars <- mom012_fixture()
  schedule <- g5_mom012_trade_schedule(
    bars,
    as.Date("2016-01-04"),
    as.Date("2018-01-31"),
    lookback_sessions = 60L,
    holding_sessions = 5L
  )
  testthat::expect_true(nrow(schedule) > 20L)
  testthat::expect_true(all(schedule$entry_index == schedule$signal_index + 1L))
  testthat::expect_true(all(schedule$exit_index - schedule$entry_index == 5L))
  testthat::expect_true(all(
    schedule$entry_index[-1L] >= schedule$exit_index[-nrow(schedule)]
  ))
  testthat::expect_true(any(
    schedule$entry_index[-1L] == schedule$exit_index[-nrow(schedule)]
  ))
  testthat::expect_true(all(schedule$direction == 1L))
  testthat::expect_true(all(schedule$direction_label == "LONG"))
  testthat::expect_true(all(schedule$past_lookback_return > 0))
})

testthat::test_that("fixed units compound equity without intra-trade rebalance", {
  bars <- mom012_fixture()
  schedule <- g5_mom012_trade_schedule(
    bars,
    as.Date("2016-01-04"),
    as.Date("2018-01-31"),
    lookback_sessions = 60L,
    holding_sessions = 5L
  )
  replayed <- g5_mom012_replay_regime(
    bars,
    schedule,
    cost_bps = 5,
    borrow_bps_annual = 0,
    regime_id = "PRIMARY"
  )
  replay <- replayed$replay
  unit_groups <- split(replay$units, replay$trade_id)
  testthat::expect_true(all(vapply(
    unit_groups,
    function(x) length(unique(signif(x, 12))) == 1L,
    logical(1)
  )))
  testthat::expect_equal(
    tail(replay$wealth, 1),
    prod(1 + replayed$trade_results$trade_return),
    tolerance = 1e-10
  )
  testthat::expect_equal(
    tail(replay$wealth, 1),
    prod(1 + replay$net_return),
    tolerance = 1e-10
  )
})

testthat::test_that("ordinary and stress costs reduce fully compounded wealth", {
  bars <- mom012_fixture()
  schedule <- g5_mom012_trade_schedule(
    bars,
    as.Date("2016-01-04"),
    as.Date("2018-01-31"),
    lookback_sessions = 60L,
    holding_sessions = 5L
  )
  gross <- g5_mom012_replay_regime(
    bars, schedule, 0, 0, "GROSS"
  )
  primary <- g5_mom012_replay_regime(
    bars, schedule, 5, 0, "PRIMARY"
  )
  stress <- g5_mom012_replay_regime(bars, schedule, 10, 0, "STRESS")
  testthat::expect_gt(
    tail(gross$replay$wealth, 1),
    tail(primary$replay$wealth, 1)
  )
  testthat::expect_gt(
    tail(primary$replay$wealth, 1),
    tail(stress$replay$wealth, 1)
  )
  testthat::expect_true(all(is.finite(stress$replay$effective_exposure)))
  testthat::expect_equal(sum(stress$replay$borrow_cost), 0)
})

testthat::test_that("Stock Atlas 02 registry freezes 100 new point-in-time names", {
  registry_path <- testthat::test_path(
    "..", "..", "registries",
    "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"
  )
  prior_path <- testthat::test_path(
    "..", "..", "registries",
    "gen5_lit_mom_01_1_stock_atlas_01_registry.csv"
  )
  registry <- utils::read.csv(registry_path, stringsAsFactors = FALSE)
  prior <- utils::read.csv(prior_path, stringsAsFactors = FALSE)
  validated <- g5_mom012_validate_atlas02_registry(registry, prior$symbol)
  testthat::expect_equal(nrow(validated$registry), 100L)
  testthat::expect_equal(
    as.integer(table(validated$registry$cohort)),
    c(75L, 25L)
  )
  testthat::expect_true(all(validated$checks$passed))
})

testthat::test_that("Stock Atlas 02 registry rejects overlap and late sources", {
  registry <- utils::read.csv(
    testthat::test_path(
      "..", "..", "registries",
      "gen5_lit_mom_01_2_stock_atlas_02_2020_breadth_attention_registry.csv"
    ),
    stringsAsFactors = FALSE
  )
  testthat::expect_error(
    g5_mom012_validate_atlas02_registry(registry, registry$symbol[[1L]]),
    "must not overlap"
  )
  late <- registry
  late$source_date[[1L]] <- "2021-01-01"
  testthat::expect_error(
    g5_mom012_validate_atlas02_registry(late),
    "known by TRAIN end"
  )
})

testthat::test_that("the defensive replay floor handles an externally supplied short", {
  bars <- mom012_fixture()
  schedule <- g5_mom012_trade_schedule(
    bars,
    as.Date("2016-01-04"),
    as.Date("2018-01-31"),
    lookback_sessions = 60L,
    holding_sessions = 5L
  )
  one_trade <- schedule[1L, , drop = FALSE]
  one_trade$trade_id <- 1L
  one_trade$direction <- -1L
  one_trade$direction_label <- "SHORT"
  shock_i <- one_trade$entry_index + 1L
  bars$open[[shock_i]] <- bars$open[[one_trade$entry_index]] * 2.5
  bars$high[[shock_i]] <- max(bars$high[[shock_i]], bars$open[[shock_i]])
  bars$low[[shock_i]] <- min(bars$low[[shock_i]], bars$open[[shock_i]])
  replayed <- g5_mom012_replay_regime(
    bars, one_trade, 5, 0, "PRIMARY"
  )
  testthat::expect_true(any(replayed$replay$bankruptcy_event))
  testthat::expect_equal(tail(replayed$replay$wealth, 1), 0)
  testthat::expect_gte(min(replayed$replay$wealth), 0)
  testthat::expect_equal(replayed$trade_results$trade_return, -1)
})
