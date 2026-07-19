# Gen5.4 Conditional-Exposure Feature Hypothesis Contract

Status: minimal primitive POC protocol frozen; implementation authority limited to the diagnostic packet  
Decision date: 2026-07-19

## Purpose

This contract defines the smallest economically interpretable feature surface for
a future leakage-safe conditional-exposure POC. It responds directly to the
ML-P8 finding that the prior Gen5.4 probability policy was about equally exposed
before favorable and unfavorable equal-weight-basket days.

For the next theory-first POC, this contract replaces the original plan's broad
40-feature starting default and generic `h3` label recommendation. It does not
rewrite or invalidate the completed ML-P0 through ML-P8 historical evidence.

The research question is:

> Using only information available after close `t`, can cross-sectional
> confirmation identify when more fixed equal-capital high-beta sleeves should
> be active for the executable open `t + 1` to open `t + 2` interval?

This is not approval to fit a model, compute new performance evidence, alter the
live bridge, or adopt an allocation or leverage policy.

## Fixed Decision And Accounting Semantics

- Canonical data remain Alpaca adjusted daily OHLCV with an explicit
  `as_of_timestamp`.
- The decision uses data available through close `t` and executes at open
  `t + 1`.
- The primary one-decision outcome is the simple total return from open `t + 1`
  to open `t + 2`. Log returns may be used inside time-additive features, but
  simple returns remain authoritative for portfolio accounting.
- Capital is divided into fixed equal sleeves, one per eligible traded asset.
- Each sleeve is binary in the minimal POC: `0 = cash`, `1 = fully active`.
- Inactive-sleeve cash remains cash; it is not redistributed to active names.
- Aggregate exposure is the sum of active fixed sleeve weights. No leverage,
  shorting, continuous probability sizing, volatility targeting, risk parity,
  Kelly sizing, or optimizer is in scope.

## Frozen Research Universe And Claim Boundary

- The eligible traded research basket is fixed as `AMD`, `NVDA`, `TSLA`,
  `MSTR`, and `AVGO`.
- These assets were selected retrospectively because their strong historical
  performance and high-beta behavior are already known. The basket is suitable
  for a bounded mechanism study, not for testing prospective asset discovery.
- No result may be presented as evidence that the system could have identified
  these names at an earlier historical date without future knowledge.
- The permitted claim is narrow: whether the frozen conditional-exposure
  mechanism discriminates favorable from unfavorable executable intervals
  within this deliberately selected research basket.
- For each target, the common peer set is the other four basket members. Peer
  membership is leave-one-out and may not change by fold or OOS outcome.

## Comparator Architecture

The POC must keep four comparisons distinct:

1. Cash/no-trade.
2. A continuously invested equal-weight basket of the eligible traded assets.
3. The same equal-weight basket scaled by the policy's realized aggregate
   exposure, to separate selection quality from broad timing/exposure.
4. Declared external context benchmarks such as `SPY`, `QQQ`, or `SMH`, used as
   economic context rather than silently substituted for the traded-basket
   benchmark.

For evaluation only, an interval is favorable when the future equal-weight
basket open-to-open return exceeds the predeclared cash-and-cost hurdle. That
future classification must never become a contemporaneous feature, scaling
input, threshold-selection input, or training-fold contaminant.

## Minimal Feature Surface

The primitive formulas below are frozen for the minimal POC. The shared
`20`-session horizon is an economic prior for approximately monthly context,
not a value to optimize from OOS results. It describes the state in which a
daily decision occurs; it does not impose a 20-session holding period.

Define `lr20(x, t) = log(close[x, t] / close[x, t - 20])` using session-aligned
adjusted closes available through close `t`.

| Role | Frozen primitive at close `t` | Raw dependencies | Expected information | Policy use |
|---|---|---|---|---|
| Target leadership | `lr20(target, t) - mean(lr20(peer, t))` over the other four basket members | Adjusted closes for the target and frozen leave-one-out peers | Positive values indicate leadership within the actual opportunity set | Opportunity |
| Opportunity-set breadth | Fraction of the other four basket members for which `lr20(peer, t) > lr20(SPY, t)` | Adjusted closes for the frozen leave-one-out peers and `SPY` | High values indicate that target leadership is accompanied by participation elsewhere in the research basket | Opportunity/context |
| Broad-market trend | `lr20(SPY, t)` | Adjusted `SPY` close | Positive trend is provisionally supportive of high-beta exposure | Risk context |
| Broad-market volatility | Annualized standard deviation of the latest 20 one-session `SPY` log returns | Adjusted `SPY` close | Volatility is primarily an interaction variable: elevated volatility with weak trend is adverse; high volatility alone is not assumed bearish | Risk context |
| Participation/liquidity | `log(median(dollar_volume[t-4:t]) / median(dollar_volume[t-64:t-5]))`, where dollar volume is adjusted close times adjusted volume | Adjusted target close and volume | Tests whether sustained recent participation is unusual relative to the target's own non-overlapping baseline; no generic "volume confirms price" assumption | Feasibility/conditional evidence |
| Semiconductor confirmation challenger | `lr20(SMH, t) - lr20(SPY, t)` for `AMD`, `NVDA`, and `AVGO` only | Adjusted `SMH` and `SPY` closes | Positive values indicate that the semiconductor group is being rewarded relative to the market | Opportunity/context challenger |

The common diagnostic feature set therefore contains five primitives. The
semiconductor challenger adds the sixth primitive only for `AMD`, `NVDA`, and
`AVGO`. It is not encoded as zero or imputed for `TSLA` or `MSTR`.

Current sleeve state belongs in the action and turnover ledger, not in the
initial predictive feature set. It may later enter a policy model only to answer
a separately declared persistence or transaction-cost question.

## Comparator Legitimacy And Missing Structure

- Leave-one-out active-basket leadership is the common cross-sectional primitive
  because it is defined for every eligible asset and directly matches the
  traded opportunity set. It measures high-beta leadership, not industry
  leadership.
- `SMH` is the frozen sector proxy for the semiconductor challenger covering
  `AMD`, `NVDA`, and `AVGO`.
- No sector proxy should be forced onto `TSLA` or `MSTR` merely to fill a column.
  A broad growth ETF is not automatically an economically valid peer group, and
  `MSTR` has no clean equity-sector proxy inside the current adjusted-equity-
  OHLCV contract.
- Sector confirmation is omitted from the common five-feature diagnostic and
  tested only in the semiconductor-specific challenger.
- The breadth primitive is explicitly named `opportunity-set breadth`. It is
  not claimed to measure broad-market breadth. A future genuine market-breadth
  feature would require a separately opened data project with point-in-time-safe
  constituent membership; today's index membership may not be projected
  backward.

## Frozen Missingness And Transformation Rules

- The common diagnostic uses strict complete-case eligibility. The target, all
  four leave-one-out peers, and `SPY` must have aligned observations and the
  full required lookback through close `t`.
- The semiconductor challenger additionally requires valid aligned `SMH`
  history.
- No cross-symbol forward filling, later-session filling, or fabricated neutral
  sector value is permitted.
- A row missing any required common input is ineligible for scoring rather than
  repaired using future or partial-panel information.
- At least 65 prior sessions are reserved for warm-up because the participation
  primitive uses five recent sessions and the preceding 60-session baseline.
- The initial diagnostic retains raw interpretable primitives: log returns for
  time-window comparisons, simple returns for P&L, a log dollar-volume ratio,
  raw breadth in `[0, 1]`, and annualized realized volatility.
- Any later centering, scaling, clipping, or learned transformation must be fit
  inside TRAIN and frozen for the corresponding OOS authority.

## Feature Admission Rules

A feature is admissible only if all of the following are true:

1. It represents a distinct economic information role rather than another
   transform of the same target-price path.
2. Its raw observations and publication/market-close availability can be stated
   exactly.
3. It can be reconstructed deterministically with data through close `t`.
4. Any imputation, scaling, clipping, ranking, filtering, or learned threshold is
   fit inside TRAIN only and frozen for OOS.
5. Its expected relationship and a plausible failure mechanism are written down
   before OOS inspection.
6. It survives a redundancy audit against the other admitted primitives.

The previous 40-feature and compact 12-feature Gen5.4 surfaces remain historical
controls. They are not an invitation to add oscillators, candlestick labels,
overlapping momentum windows, or feature-importance-selected variants to this
minimal surface.

## Leakage And Multiple-Testing Guardrails

- Every trailing window ends at close `t`; no centered windows or revised future
  membership information are permitted.
- Target and context bars must be session-aligned. Missing context observations
  cannot be filled from a later session.
- The eligible traded universe and comparison panel are declared before each
  assessment and may not be selected from OOS winners.
- Labels that cross a TRAIN/OOS boundary are ineligible for TRAIN fitting.
- Feature construction may use fixed arithmetic formulas globally, but any
  empirically estimated parameter is TRAIN-only.
- Feature-family comparisons must be predeclared and few. OOS evidence cannot be
  used to choose horizons, proxies, transformations, or interaction terms.
- Results must be reported by fold, year, and symbol so that a single asset or
  regime cannot masquerade as a general relationship.

## Falsification Contract

The hypothesis fails to earn modeling expansion if the frozen OOS evidence shows
any of the following:

- Mean exposure is not materially higher before favorable basket intervals than
  before unfavorable intervals.
- Any apparent benefit disappears against the exposure-matched equal-weight
  comparator.
- Separation is concentrated in one symbol, year, or a small number of extreme
  observations.
- The relationship is contemporaneous but does not survive the executable
  next-open-to-following-open interval.
- The sign or ordering of the primitive effects is unstable across folds.
- Turnover and a predeclared trading-cost hurdle remove the distinction.
- Improvement appears only after searching many horizons, proxies, or feature
  combinations.

Passing this diagnostic would justify a small model comparison; it would not
establish alpha, allocation acceptance, or live readiness.

## Frozen Primitive POC Validation Protocol

The first implementation is a feature-and-outcome diagnostic packet only. It
must not fit a GLM, XGBoost model, probability calibration, or policy threshold.

- Per-sleeve outcome: target simple return from open `t + 1` to open `t + 2`.
- Portfolio-context outcome: equal-weight basket simple return over the same
  executable interval. The target outcome answers which sleeve was favorable;
  the basket outcome separately evaluates aggregate exposure context.
- Fold ladder: twenty consecutive quarterly OOS authorities from `2020Q1`
  through `2024Q4`.
- Each authority uses the preceding eight quarters as TRAIN and is frozen for
  its OOS quarter. Annual views stitch quarterly evidence for reporting only.
- Every fold is reported; no quarter may be excluded after inspection.
- Primitive ordering uses five empirical bins defined from the corresponding
  TRAIN rows and then frozen into OOS. Bins are diagnostic, not selected policy
  thresholds.
- Favorable diagnostic outcomes exceed zero. Costs are not subtracted from
  every daily label because continuing positions do not retrade every day.
- A fixed top-two-TRAIN-quintile exposure proxy may be used only to make
  turnover and cost sensitivity auditable. It is not a promoted trading rule.
- The base cost is `10` basis points per one-way notional change; the stress
  cost is `20` basis points. Costs apply only to sleeve-state changes.
- Directional promotion requires positive high-minus-low return separation and
  positive bin ordering in at least `12 / 20` quarterly folds, no symbol-year
  cell above `50%` of absolute separation contribution, positive selection
  excess after the base cost, and no reversal after the stress cost.
- Broad-market volatility is an interaction/context primitive and is not forced
  through an univariate monotonic promotion gate.
- The continuation mechanism must not advance unless both target leadership and
  opportunity-set breadth clear their frozen feature-level gates.
- `SMH` confirmation is judged separately on the semiconductor subset and may
  not rescue failure of the common mechanism.

Fold stability, economic effect size, concentration, executable timing, and
cost robustness govern this gate. A naive independent-observation `p < 0.05`
rule is not authoritative for the shared-date, regime-dependent panel.

## Implementation Boundary

The frozen protocol authorizes construction and inspection of the primitive POC
packet. Model fitting, threshold search, allocation, leverage, live-advice
changes, and execution remain closed. The next operator gate depends on the
completed primitive readout: STOP and revise the hypothesis if the common core
fails, or explicitly authorize a small model comparison if it passes.

## Frozen Leadership x Participation Confirmation

The primitive POC stopped the original confirmation mechanism because
opportunity-set breadth failed, while target leadership and dollar-volume
participation passed individually. Those individual results are treated as
hypothesis-generating evidence, not permission to delete breadth and fit a
model on the same OOS period.

The separately accepted confirmation question is:

> Does 20-session cross-sectional leadership persist when accompanied by
> abnormal target-specific dollar-volume participation, without requiring peer
> breadth or sector confirmation?

The bounded confirmation protocol is:

- Confirmation authorities: `2025Q1` through `2026Q2` only.
- Each authority uses the preceding eight quarters as TRAIN.
- High leadership and high participation each mean at or above the pooled TRAIN
  `60th` percentile, frozen into the corresponding OOS quarter.
- State A: high leadership and high participation.
- State B: high leadership and low participation.
- State C: low leadership and high participation.
- State D: low leadership and low participation.
- The outcome remains the target simple return from open `t + 1` to open
  `t + 2`.
- State A must beat both State B and State C. Beating only State D does not
  confirm that the two inputs add information jointly.
- Correct State-A ordering is required in at least `4 / 6` OOS quarters.
- Pooled State A minus State B and pooled State A minus State C must both be
  positive.
- A fixed State-A exposure proxy must have positive exposure-matched selection
  excess after `10` basis points per one-way change and must not reverse after
  the `20` basis-point stress cost.
- No single symbol may exceed `50%` of absolute joint-contrast contribution.
- Failure is a STOP. A `3 / 6` result is inconclusive and does not authorize a
  threshold or horizon change.

The confirmation packet must include a four-state visual, quarterly contrast
chart, representative all-symbol state tapes, cost-robustness chart, and an
explicit pass/stop checklist. It fits no model and changes no live behavior.

## Completed Leadership x Participation Readout

The frozen confirmation ran on `2025Q1` through `2026Q2` and returned `STOP`.
State A beat both State B and State C in only `2 / 6` quarterly OOS folds versus
the required `4 / 6`. Pooled State A averaged `+5.2 bp`, compared with `+20.9
bp` for State B and `-5.6 bp` for State C. The resulting pooled contrasts were
`-15.7 bp` for A minus B and `+10.9 bp` for A minus C.

The fixed State-A exposure proxy produced selection-excess sums of `-0.0342`
after the `10 bp` base cost and `-0.0659` under the `20 bp` stress cost. The
largest symbol contribution was `45.2%`, which passed the concentration cap but
did not rescue the failed ordering, A-minus-B, and cost gates. Model-fit count
remained zero.

This result closes the leadership × participation confirmation without
authorizing a different percentile, horizon, interaction, model, allocation,
or live behavior. The next research gate is theory-first selection of a
genuinely distinct point-in-time information family rather than another nearby
OHLCV transformation.
