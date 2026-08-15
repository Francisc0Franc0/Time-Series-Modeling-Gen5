# HYP-REG-01.1 ATR-Percent Volatility-Regime POC Contract

Status: `DIAGNOSTIC_COMPLETE_STOP_BEFORE_STRATEGY_OVERLAY`

## Where This Fits

This is the first strategy-independent volatility-regime experiment after the
daily/30-minute momentum POC series. It tests whether a simple causal state
label forecasts the magnitude of future movement. It does not test whether any
strategy earns money in a state and does not authorize strategy routing.

## Question

Does an asset's daily ATR as a percentage of price, ranked against only its own
preceding history, provide a stable and portable forecast of subsequent
directionless normalized range?

## Hypothesis ID and Nomenclature

- Lane: `HYP-REG-01`
- Version: `HYP-REG-01.1`
- Name: Asset-Relative ATR% Volatility States
- A decimal increment requires a substantive mechanics change.
- A volatility-impulse filter is reserved for `HYP-REG-02.1`; it is not part of
  this run.

## Authority Boundary

This lane may:

- calculate causal volatility measurements;
- assign diagnostic low, medium, and high volatility states;
- assess future directionless range;
- compare the primary score with fixed diagnostic volatility benchmarks;
- report state persistence, occupancy, transitions, and sensitivity.

This lane may not:

- calculate strategy returns, PnL, Sharpe, drawdown, hit rate, or alpha;
- gate, enter, exit, size, lever, allocate, or route a strategy;
- inspect or use any session on or after 2024-01-02;
- select assets, parameters, or thresholds because their outcomes look best;
- promote a filter to live, advice, portfolio, or execution authority.

## Frozen Data Scope

- Provider: Alpaca.
- Bars: adjusted daily OHLCV.
- Analysis period: 2018-01-02 through 2023-12-29.
- Prehistory query start: 2016-01-04. A bounded refresh requested 2015 history,
  but Alpaca returned no rows before 2016-01-04 for any of the 26 assets.
- Explicit query as-of: 2026-08-14 17:30:00 America/New_York.
- Panel: the 26 assets frozen for the intraday momentum POC: 24 diverse stocks
  plus SPY and QQQ.
- SPY supplies the expected-session calendar.
- Any missing or invalid OHLC row is reported. No imputation is allowed.
- The available 503 pre-analysis sessions fully warm the primary ATR14 / 252
  specification. ATR14 / 504 sensitivity labels begin after their remaining
  natural warm-up inside 2018 and are compared only where both labels exist.
- The entire 2018-2023 period remains development evidence because it has been
  examined in earlier lanes. It is not represented as untouched confirmation.

## Primary Measurement

For session `t`:

`TR_t = max(high_t - low_t, abs(high_t - close_(t-1)), abs(low_t - close_(t-1)))`

ATR uses Wilder's recursive smoothing with length 14. The initial value is the
simple average of the first 14 finite true ranges. Thereafter:

`ATR_t = ((13 * ATR_(t-1)) + TR_t) / 14`

Normalized ATR is:

`ATR_pct_t = 100 * ATR_t / close_t`

The causal percentile score compares today's ATR% with the preceding 252
completed ATR% observations, excluding today. Ties use a mid-rank:

`score_t = (count(history < current) + 0.5 * count(history == current)) / 252`

The score calculated after close `t` is first available to govern a hypothetical
decision on `t+1`. This POC does not make that decision.

## Frozen Operational States

The raw state is:

- `LOW` when score < 0.30;
- `MEDIUM` when 0.30 <= score <= 0.70;
- `HIGH` when score > 0.70.

The operational state uses hysteresis:

- enter `LOW` below 0.30; leave it only above 0.40;
- enter `HIGH` above 0.70; leave it only below 0.60;
- otherwise retain or return to `MEDIUM`;
- a jump across both boundaries may move directly from `LOW` to `HIGH` or from
  `HIGH` to `LOW`.

The first eligible state starts from the raw state. There is no minimum-duration
or retrospective state editing rule.

## Directionless Prediction Targets

Normalized true range is:

`NTR_t = TR_t / close_(t-1)`

For horizons 1, 5, and 20 sessions, the target paired with state date `t` is the
mean NTR over sessions `t+1` through `t+h`. It contains no price direction and
no strategy outcome.

Descriptive calculations may retain every eligible date. Inferential summaries
must also use deterministic non-overlapping samples: every `h`-th eligible
observation per asset, anchored at that asset's first eligible observation.

## Frozen Diagnostic Comparators

The primary score is compared, without winner selection, with:

1. `CURRENT_NTR_PERCENTILE`: today's one-session NTR ranked against its prior
   252 observations, a naive persistence benchmark.
2. `EWMA_VOL_PERCENTILE`: an exponentially weighted close-to-close log-return
   volatility estimate with fixed lambda 0.94, ranked against its prior 252
   observations.

These comparators do not create alternate strategy filters in this lane.

## Validation Surfaces

### Predictive ordering

- Spearman association between each causal score and future mean NTR.
- Median future mean NTR by operational state.
- `HIGH / LOW` and `MEDIUM / LOW` median-range ratios.
- Per-asset monotonic-ordering incidence.
- Full-overlap descriptive and non-overlapping inferential summaries are shown
  separately.

### State behavior

- State occupancy by asset and panel.
- Transition matrix.
- Switches per year.
- Run-count and dwell-time distribution.
- One-session state reversals.

### Portability

- Identical mechanics for all 26 assets.
- Per-asset and pooled-panel outputs.
- No asset replacement or outcome-based exclusion.

### Sensitivity without selection

The primary `ATR14 / 252-session` score is compared for label agreement with:

- ATR10 / 252;
- ATR20 / 252;
- ATR14 / 126;
- ATR14 / 504.

These are robustness diagnostics only. No sensitivity setting can replace the
primary specification in this run.

## Interpretation Gates

The classifier is considered descriptively coherent when:

- the state labels are causal and reproduce deterministically;
- future normalized range is ordered `HIGH > MEDIUM > LOW` at most or all
  horizons in the pooled panel;
- a majority of assets show `HIGH > LOW` at the 5- and 20-session horizons;
- state occupancy is non-degenerate and switches are not dominated by
  one-session reversals;
- the primary score is not obviously inferior to both fixed benchmarks;
- nearby sensitivity specifications retain materially similar labels.

These are discussion gates, not automatic promotion criteria. Passing them
would authorize only a conversation about a separately frozen strategy-overlay
POC.

## Required Artifacts

- frozen registry and run specification;
- query health, coverage, and integrity tables;
- daily score/state ledger;
- predictive summaries by horizon, state, and asset;
- benchmark comparison;
- occupancy, transition, dwell, and sensitivity tables;
- state-labeled representative tapes;
- cross-asset and horizon-level visual diagnostics;
- concise report and referenced PowerPoint;
- explicit STOP before strategy gating or confirmation access.
