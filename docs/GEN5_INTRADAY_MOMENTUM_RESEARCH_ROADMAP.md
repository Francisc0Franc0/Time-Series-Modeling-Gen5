# Gen5 Intraday Momentum Research Roadmap

Status: `ATR_LOW_ENTRY_OVERLAY_DEVELOPMENT_FAILED_CONFIRMATION_NOT_RUN`

Decision references: `D125`, `D126`, `D127`, `D128`

## Purpose

This roadmap records the approved and now completed unfiltered research
sequence for testing simple momentum and moving-average ideas on daily and
30-minute stock bars. The completed evidence does not authorize portfolio
construction, a regime filter, confirmation access, or live behavior.

The immediate objective is educational and diagnostic: reconstruct a simple
strategy that the operator previously traded successfully in TSLA and AMD,
then determine which parts of its apparent success came from signal timing,
asset and market conditions, leverage, and historical regime. A fully
deployable result is not expected from these first unfiltered lanes.

## Intellectual provenance and planned identifiers

The roadmap crosses two existing research phylogenies without merging them:

| Planned identifier | Provenance | Question |
|---|---|---|
| `HYP-MOM-06.1` | Operator hypothesis | What follows from a fresh daily SMA8/SMA14 long/cash crossover? |
| `HYP-IMOM-01.1` | Operator hypothesis | What follows from the same SMA8/SMA14 rule on regular-session 30-minute bars? |
| `HYP-IMOM-02.1` | Operator hypothesis | Can a fresh price/anchor-SMA cross on 30-minute bars improve the return/protection bargain? |
| `LIT-IMOM-01.1` | Literature derivative | Does a session-scaled 30-minute adaptation of Chan's interday momentum selection and sleeve policy transport causally? |

`IMOM` denotes intraday-bar momentum. It does not imply that positions must be
closed intraday. The initial designs may hold across sessions and remain
long-only.

The identifiers were frozen and implemented together under
`docs/GEN5_INTRADAY_MOMENTUM_POC_SERIES_CONTRACT.md`. Results are recorded in
`operator_hypothesis_lab/docs/GEN5_INTRADAY_MOMENTUM_POC_SERIES_RESULTS.md`.

## Research order

### Phase 0 — Intraday data and replay admission

Before any strategy result is computed:

1. Extend Alpaca scope in an isolated intraday module rather than silently
   changing the stable adjusted-daily data contract.
2. Freeze one historical stock feed and one corporate-action adjustment
   policy.
3. Request explicit bounded timestamps and preserve the repository's
   `as_of_timestamp` invariant.
4. Use regular US trading hours only for the first POCs.
5. Expect 13 half-hour bars on a normal session; identify early closes,
   missing bars, duplicated timestamps, partial sessions, and timezone errors.
6. Preserve overnight gaps rather than treating the bar sequence as uniformly
   spaced clock time.
7. Verify historical symbol identity, split handling, pagination, and cache
   determinism.
8. Establish completed-bar signals, next-bar modeled execution, and a
   mandatory one-complete-bar-delay sensitivity.

No strategy lane proceeds until its required data coverage passes. A data
failure is recorded rather than repaired by silently replacing assets.

### Phase 1 — Canonical SMA8/SMA14 reconstruction

Run the same minimal state machine at daily and 30-minute frequency:

\[
\text{LONG}_t \iff SMA_8(t) > SMA_{14}(t).
\]

- A fresh completed-bar cross above generates a long signal.
- Entry is modeled no earlier than the next bar.
- A fresh completed-bar cross below generates an exit.
- Exit is modeled no earlier than the next bar.
- Every evaluation block starts in cash.
- Positions may remain open overnight.
- No shorts.

`8/14` is canonical because it reconstructs the operator's lived TSLA/AMD
experience. Those assets are educational case studies and may support detailed
trade tapes, but they cannot establish unbiased generalization because their
past success is already remembered.

The daily and 30-minute versions are separate estimands. Eight and fourteen
daily sessions describe a multiweek trend, while eight and fourteen half-hour
bars describe roughly four hours and a little more than one regular session.

First reconstruct the fixed `8/14` rule. Only a separately frozen revision may
search a compact neighboring horizon family. Do not select the best pair over
the full history and report it as fresh evidence.

### Phase 2 — Session-scaled price/SMA cross

Port the narrow HYP-MOM-02 price-cross question rather than mechanically
calling 200 half-hour bars equivalent to SMA200 daily:

\[
S \in \{65, 130, 260, 520\}.
\]

These anchors represent approximately 5, 10, 20, and 40 regular trading
sessions. Test two predeclared exit families:

1. symmetric: enter after price crosses above `S`; exit after price crosses
   below `S`;
2. asymmetric: use the same entry but exit after price crosses below
   `round(S/4)`, the session-scaled analogue of the daily 200/50 relationship.

All crosses use completed bars and next-bar modeled execution. Parameter
selection, if opened, occurs inside TRAIN only and is tested in later calendar
blocks.

### Phase 3 — Session-scaled Chan momentum

Preserve Chan's conceptual question:

\[
R_{t-L,t} \quad \text{predicts} \quad R_{t,t+H}.
\]

The initial planning grid is:

\[
L \in \{13, 26, 65, 130, 260\}, \qquad
H \in \{13, 26, 65\}.
\]

This corresponds approximately to 1-, 2-, 5-, 10-, and 20-session lookbacks
and 1-, 2-, or 5-session holds. It deliberately remains closer to swing
trading than scalping.

TRAIN correlation calculations retain Chan's minimum non-overlap step. The
adaptation must also address dependence and seasonality specific to intraday
data:

- cluster or resample by whole sessions or weeks;
- preserve the within-day opening, midday, and closing structure in null
  controls;
- score candidates across calendar subperiods rather than treating every bar
  as an independent observation;
- keep horizon selection inside TRAIN;
- compare Chan's overlapping `1/H` sleeves with a separately labeled
  all-capital hold variant only if that variant is frozen before its outcome.

## Development and OOS structure

More bars do not imply proportionally more independent evidence. The default
planning structure is:

- at least 12–24 calendar months in the initial TRAIN interval;
- quarterly causal outer-test blocks;
- expanding or rolling TRAIN windows, frozen per lane;
- multiple outer blocks before any promotion discussion;
- monthly TRAIN score components so a few volatile days cannot dominate;
- a final later calendar interval kept sealed.

Exact dates will be frozen only after the intraday coverage audit. Existing
daily windows are not automatically inherited, and later outcomes are not
opened merely because they were inspected in a different daily-bar lane.

## Leverage and capital-accounting policy

Every strategy is evaluated at both `1x` and `1.8x`. The operator's remembered
TSLA/AMD success occurred at approximately `1.8x`, so absolute wealth growth
is a relevant outcome rather than an artifact to discard.

The interpretation is separated into two questions:

1. Did the timing rule add value before leverage?
2. What return and loss path did the 1.8x implementation create after
   financing and trading costs?

### Selection invariant

All parameter and policy selection uses `1x` primary-cost TRAIN evidence.
`1.8x` cannot select a horizon, rescue a failed 1x timing result, or open a
promotion gate. It is a frozen implementation overlay evaluated after the same
policy has been selected.

### Planned 1.8x mechanics

- At each new entry, target notional is `1.8 x current strategy equity`.
- Shares remain fixed until exit; there is no continuous leverage rebalance.
- Profits and losses affect equity and therefore the size of later entries.
- Borrowed notional, elapsed-time financing, and transaction costs are
  ledgered explicitly.
- The exact financing rate, maintenance-margin proxy, and forced-liquidation
  convention must be frozen before a run.
- Report minimum equity, maximum drawdown, time underwater, financing paid,
  and any nonpositive-equity or maintenance-proxy breach.

This design measures aggressive compounding more faithfully than multiplying
a finished 1x return by 1.8.

## Baselines and controls

The following comparisons are mandatory where applicable:

| Question | Required comparison |
|---|---|
| Did the rule create absolute growth? | Cash and 1x buy-and-hold |
| Did timing beat ordinary ownership? | Same-asset buy-and-hold over the same calendar block |
| Did the exact timing matter? | Exposure- and trade-count-matched calendar shifts |
| Did 30-minute information earn its complexity? | Corresponding daily strategy with the same economic interpretation |
| Did leverage add return efficiently? | 1x strategy versus the unchanged policy at 1.8x |
| Did leverage rather than timing explain the wealth outcome? | 1.8x strategy versus 1.8x buy-and-hold and 1.8x matched timing controls under the same financing convention |
| Was execution fragile? | Next-bar primary replay versus one-complete-bar-delay sensitivity |
| Did costs consume the apparent edge? | Gross, primary-cost, and stress-cost views |

The 1.8x buy-and-hold baseline must use an explicitly frozen fixed-quantity
debt convention rather than an implicit daily rebalance. A same-leverage,
exposure-matched timing control is the cleanest attribution baseline for an
intermittent strategy.

Report absolute and risk-adjusted evidence together:

- terminal return and annualized return where meaningful;
- dollar/equity path from a common starting capital;
- Sharpe and downside-risk statistics;
- maximum drawdown, time underwater, and recovery duration;
- hit rate, median and mean trade return, trade PnL, and right-tail dependence;
- turnover, exposure, holding duration, and costs;
- leverage financing and margin-risk diagnostics.

Neither terminal wealth nor Sharpe alone governs the interpretation.

## Required visual and behavioral audits

Each completed lane should include:

- canonical TSLA and AMD tapes;
- a representative winner, loser, whipsaw path, and extended-trend path;
- entry and exit concentration by time of day;
- overnight versus same-session contribution;
- gross/primary/stress wealth curves at 1x and 1.8x;
- drawdown and underwater paths;
- direct baseline and timing-control comparisons;
- asset, sector, liquidity, volatility, and calendar-block breadth.

Intraday volume, if used diagnostically, must be normalized against the same
time-of-day slot. The opening bar cannot be compared naively with midday.

## Later regime-filter discussion

After all three unfiltered strategy families are documented, pause before
adding filters. The next activity is a dedicated retrospective regime audit,
not an immediate strategy rescue.

Known strong TSLA/AMD periods may be used transparently to learn candidate
mechanisms such as:

- realized-volatility level and expansion;
- asset, sector, and broad-market trend alignment;
- relative strength;
- directional efficiency or trend quality;
- time-of-day-normalized volume or participation;
- catalyst versus ordinary sessions.

That audit is hypothesis generation only. Any regime rule that advances must
be small, causal, scale-normalized, broadly shared across a predeclared liquid
and sufficiently volatile stock domain, and tested under nested walk-forward
validation against the unfiltered strategy, simple market permission, no
trade, and exposure-matched controls.

The design goal is not universal applicability. It is a shared model that can
transport across a predeclared eligible domain without asset-specific tuning.

## Current stop state

`ATR_LOW_ENTRY_OVERLAY_DEVELOPMENT_FAILED_CONFIRMATION_NOT_RUN`

The unfiltered momentum series is complete. The separately frozen
`HYP-REG-01.1` daily ATR%-percentile diagnostic also completed without using
strategy outcomes: all 26 assets showed higher future directionless range in
`HIGH` than `LOW` at 1-, 5-, and 20-session horizons, while hysteresis created
durable but non-permanent states. This validates a volatility sensor, not a
trading rule.

Do not now:

- treat the failed `ATR_LOW_OFF` overlay as a strategy improvement;
- search ATR length, memory, thresholds, assets, years, or allowed-state
  combinations on the same evidence;
- attach the state to an intraday strategy without a separately frozen causal
  hypothesis and controls;
- access the sealed 2024+ interval;
- form a portfolio or change advice/live behavior.

The separately frozen `HYP-REG-01.2` test supplied that first strategy overlay.
It suppressed only fresh daily SMA8/SMA14 entries whose causal signal-close
state was `LOW`, while preserving every exit and all parent mechanics. Median
annual return fell from `8.95%` to `4.44%`; drawdown improved, but Sharpe,
asset breadth, calendar breadth, and exposure-near placebo specificity failed.
Do not run confirmation or search alternate allowed-state combinations on the
same evidence. Preserve the daily ATR% classifier as a diagnostic and reject
this particular permission rule.
