# HYP-REG-01.2 ATR% Permission Overlay Contract

Status: `STOP_DEVELOPMENT_OVERLAY_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Where This Fits

`HYP-REG-01.1` established that an asset-relative ATR% percentile is a causal,
portable predictor of future directionless range. `HYP-REG-01.2` is the first
separate test of whether that accepted sensor adds value to one unchanged,
well-characterized strategy. It remains DEVELOPMENT evidence and cannot grant
confirmation, portfolio, advice, or live authority.

## Question

Does suppressing fresh daily SMA8/SMA14 entries when the asset is in the
accepted `LOW` ATR% state improve the return/protection bargain relative to the
unchanged unfiltered strategy and exposure-near regime-timing placebos?

## Frozen Identity

- Lane: `HYP-REG-01`
- Version: `HYP-REG-01.2`
- Name: ATR% Low-State Entry-Permission Overlay
- Parent sensor: `HYP-REG-01.1`
- Parent strategy: `HYP-MOM-06.1`
- Evidence stage: `DEVELOPMENT_REUSED_WINDOW`

The decimal increment is substantive: the accepted diagnostic state is now
allowed to control entry permission for one existing strategy. The ATR
mechanics and SMA mechanics themselves remain unchanged.

## Data Authorities and Causal Join

The two parent lanes retain their original data authorities:

1. ATR state labels come from the accepted `HYP-REG-01.1` adjusted-daily state
   ledger. The state for session `t` is known only after that close.
2. SMA signals and next-open executions use daily bars reconstructed from the
   admitted regular-session 30-minute Alpaca SIP archive, exactly as in
   `HYP-MOM-06.1`.
3. A signal observed after close `t` consults only the ATR state dated `t` and
   may enter at open `t+1`.
4. The parent strategy calendar retains the ten globally excluded common SIP
   archive-gap sessions documented in `D126`. The ATR ledger contains those
   dates, but they cannot become strategy signals or executions. Admission
   therefore requires 1,499 strategy sessions, 1,509 state sessions, zero
   strategy dates lacking a state, and exactly ten state-only dates per asset.

The surfaces are intentionally not blended into a new OHLC series. The runner
must reproduce the unfiltered parent summaries from the retained parent packet
before interpreting the overlay.

## Frozen Universe and Window

- Registry: the unchanged 26-asset `HYP-REG-01.1` registry.
- Primary decision panel: the 24 registered stocks.
- Reference-only assets: SPY and QQQ.
- DEVELOPMENT: 2018-01-02 through 2023-12-29, evaluated as six calendar-year
  asset cells exactly like the fixed parent lane.
- 2024-01-02 and later remain sealed.
- All assets start each calendar year in cash and must receive a fresh
  in-year crossover before entry.

## Parent Strategy Mechanics

- Simple moving averages of adjusted/reconstructed daily close: fast 8,
  slow 14.
- Fresh `SMA8 > SMA14` cross after close: candidate entry at the next open.
- Fresh `SMA8 <= SMA14` cross after close: exit at the next open.
- Long/cash only.
- No deferred entry if a crossover is not acted upon.
- No stop, profit target, holding-period cap, or other confirmation.

## Overlay Mechanics

Primary policy `ATR_LOW_OFF`:

- if the fresh entry crossover's signal-close state is `LOW`, skip the entry;
- if the state is `MEDIUM` or `HIGH`, execute the unchanged next-open entry;
- if an entry is skipped, remain in cash until a later fresh crossover;
- once a trade is open, ATR state changes do not alter it;
- the unchanged SMA8/SMA14 cross-down remains the only ordinary exit.

The primary policy is fixed before outcomes. `MEDIUM_ONLY`, `HIGH_ONLY`,
`HIGH_OFF`, threshold searches, memory searches, and state combinations are
prohibited.

## Accounting

- Initial wealth: $100,000 per asset-year cell.
- Primary: 1x, 5 bp per side, no financing at 1x.
- Stress: 1x, 10 bp per side.
- Secondary mechanical view: fixed-quantity 1.8x with 6% primary and 10%
  stress annual financing, using the existing parent replay.
- Profits and losses compound within each annual cell; annual returns are
  compounded for asset-level breadth summaries.
- Only 1x primary evidence may govern the decision.

## Baselines and Placebos

Direct baselines:

- unchanged unfiltered SMA8/SMA14;
- buy-and-hold at the same leverage and cost assumptions;
- cash.

Regime-alignment null:

- 200 deterministic circular shifts of the complete within-year ATR-state
  sequence for every asset-year;
- each shift preserves that cell's state occupancy and serial run structure
  but intentionally breaks the historical alignment between the state and
  crossover;
- for the panel decision, retain the 40 shift IDs whose stock-panel median
  exposure is closest to the actual overlay exposure;
- closeness is determined only from exposure, never from return;
- report the actual overlay's midrank percentile within those 40 controls and
  its excess over their median return.

The shifted masks are noncausal null controls, not executable alternatives.

## Required Outputs

- parent-reproduction audit;
- annual asset-level summaries for unfiltered, overlay, and buy-and-hold;
- 1x primary and stress results, with 1.8x secondary views;
- total return, Sharpe, maximum drawdown, exposure, turnover, trade count,
  hit rate, mean/median trade, holding duration, underwater time, financing,
  and maintenance-proxy diagnostics;
- retained-versus-removed parent-trade audit by signal state;
- cross-asset and cross-year breadth;
- 200-shift control distribution and 40-shift exposure-near decision subset;
- representative AMD, TSLA, improvement, and degradation tapes;
- explicit gate table and STOP/PASS state.

## Frozen Gates

All gates must pass for `PASS_TO_CONFIRMATION_DISCUSSION`:

1. **Integrity:** 26 assets, six annual cells each, 24-stock primary panel,
   unique causal state joins, the documented `1,499 / 1,509 / 0 / 10`
   calendar pattern, no 2024+ rows, and no missing crossover states.
2. **Parent reproduction:** rerun unfiltered 1x primary asset-year returns match
   the retained `HYP-MOM-06.1` packet within `1e-10`.
3. **Panel return:** median 1x primary annual return for `ATR_LOW_OFF` exceeds
   the unfiltered median.
4. **Asset breadth:** at least 15 of 24 stocks have higher six-year compounded
   return under the overlay.
5. **Calendar breadth:** stock-panel median overlay excess is positive in at
   least four of six years.
6. **Protection and risk-adjustment:** median maximum drawdown is no worse and
   median Sharpe is no lower than unfiltered.
7. **Absolute viability:** median overlay annual return remains positive.
8. **Regime specificity:** actual overlay median return is at or above the
   80th percentile of the 40 exposure-nearest circular-state controls and
   exceeds their median.

Failure records `STOP_DEVELOPMENT_OVERLAY_GATES_FAILED_CONFIRMATION_NOT_RUN`.
Passing opens only a discussion about one frozen 2024+ confirmation. It does
not automatically open confirmation or deployment.

## Prohibited Scope

Do not:

- modify ATR length, percentile memory, thresholds, or hysteresis;
- modify SMA horizons, fresh-cross semantics, or exits;
- select assets, years, states, or leverage after outcomes;
- add trend, breadth, relative-strength, volume, catalyst, or other filters;
- inspect 2024+;
- form a portfolio or change advice/live behavior.
