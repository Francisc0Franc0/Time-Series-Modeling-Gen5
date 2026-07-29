# Literature-Grounded Mean-Reversion Quantitative Gate Review

## Status

`COMPLETED_WITHOUT_FURTHER_GATE_RELAXATION`

This review records the quantitative reasoning used to define the separately
named `LIT-MR-02.2` pair and `LIT-MR-03.2` triplet challenger lanes. It does
not alter, erase, or reinterpret any `02.1` or `03.1` result.

## Why A New Revision Is Required

Changing an admission gate after inspecting results is a substantive research
change even when the trading rule itself is unchanged. Decimal revisions are
therefore appropriate:

- `LIT-MR-02.2`: the `02.1` rolling-beta pair rule with graded admission
  evidence; and
- `LIT-MR-03.2`: the `03.1` exact-rank-one Johansen triplet rule with measured
  threshold easing.

Both revisions retain daily adjusted bars, the 20-session z-score, entry at
`+/-1`, zero-crossing exit, next-open execution, and 5/10 bp turnover costs.

## What The Strict Screens Revealed

These counts are descriptive diagnostics from already inspected 2016-2020
TRAIN batches. They motivate the challenger design but cannot validate it.

### Pair evidence

Across 52 prior primary pair instances:

- integrity passed `52 / 52`;
- positive-beta coverage passed `44 / 52`;
- the 30-trade and 10-per-direction support rule passed `52 / 52`;
- the 95% two-sided lower return bound passed `0 / 52`;
- hit rate above 50% passed `2 / 52`;
- the matched random-sign p90 control passed `2 / 52`;
- at least three positive TRAIN years passed `6 / 52`; and
- the 95% two-sided upper convergence bound passed `0 / 52`.

Only two pairs had both a positive mean return point estimate and a negative
forward-convergence point estimate. The strict screen was therefore rejecting
mainly on uncertainty and economic evidence, not on insufficient trade count.

### Triplet evidence

Across 36 prior triplet instances:

- integrity and the frozen I(1) diagnostic passed `36 / 36`;
- exact rank one passed `15 / 36`;
- cosine at least 0.85 passed `19 / 36`;
- half-life between 2 and 60 sessions passed `27 / 36`;
- the 30-trade and 10-per-direction support rule passed `36 / 36`;
- the 95% two-sided lower return bound passed `4 / 36`; and
- the 95% two-sided upper convergence bound passed `13 / 36`.

Among the 15 exact-rank-one triplets, five had both a positive mean return
point estimate and a negative convergence point estimate.

## Gate Classification

### Pair challenger

| Item | `02.1` | `02.2` | Role |
|---|---|---|---|
| Integrity and chronology | all checks pass | unchanged | mandatory |
| Positive rolling beta | at least 95% | unchanged | mandatory |
| Completed-trade support | 30 total; 10 each direction | 24 total; 8 each direction | mandatory |
| Cost-aware mean uncertainty | 2.5th percentile above zero | 10th percentile above zero | mandatory |
| Hit rate | above 50% | reported only | diagnostic |
| Random-sign control | observed mean beats p90 | unchanged | mandatory |
| Positive TRAIN years | at least 3 of 5 | reported only | diagnostic |
| Forward convergence uncertainty | correlation negative and 97.5th percentile below zero | correlation negative and 90th percentile below zero | mandatory |

The 10th-percentile lower bound is a one-sided 90% bootstrap requirement. It
is weaker than the prior effective 97.5% one-sided standard but still excludes
point-estimate-only nominations. The unchanged random-sign p90 control
prevents this easing from becoming a simple positive-return screen.

The hit-rate veto is removed because a positive-expectancy strategy can win
less than half the time when average wins exceed average losses. The calendar
year veto is removed because uneven opportunity timing can make an arbitrary
year boundary a noisy proxy for stability. Both remain visible.

### Triplet challenger

| Item | `03.1` | `03.2` | Role |
|---|---|---|---|
| Integrity and mixed-sign vector | all checks pass | unchanged | mandatory |
| All components I(1) | frozen ADF diagnostic | unchanged | mandatory |
| Johansen rank | exactly one | unchanged | mandatory |
| Split-TRAIN vector cosine | at least 0.85 | at least 0.80 | mandatory |
| Spread half-life | 2 to 60 sessions | 2 to 90 sessions | mandatory |
| Completed-trade support | 30 total; 10 each direction | 24 total; 8 each direction | mandatory |
| Cost-aware mean uncertainty | 2.5th percentile above zero | 10th percentile above zero | mandatory |
| Forward convergence uncertainty | correlation negative and 97.5th percentile below zero | correlation negative and 90th percentile below zero | mandatory |

A cosine of 0.85 limits the angle between split-TRAIN exposure vectors to
about 31.8 degrees; 0.80 allows about 36.9 degrees. This is a measured
five-degree expansion, not removal of the stability requirement.

The 90-session upper half-life admits relationships that may take roughly one
quarter to decay by half. The two-session lower bound remains because a
relationship that reverts faster than next-open daily execution can plausibly
capture movement unavailable to the strategy.

## Support Interpretation

Twenty-four completed trades still produce a noisy estimate. At a 50% hit
rate, the binomial standard error is about 10.2 percentage points. Eight trades
in one direction are even less precise. This is why direction-level hit rates
remain descriptive and why bootstrap uncertainty, costs, and convergence are
still mandatory.

## Two Clearly Separated Research Lanes

### Retrospective curiosity lane

- Apply the new gates to every unique previously tested pair and every
  previously tested triplet.
- Run 2021-2023 DEVELOPMENT for every retrospective relaxed-gate survivor.
- Report all survivors and outcomes without choosing a winner.
- Label the exercise post-hoc and descriptive.
- Make no discovery, validation, or alpha claim.

This answers "what would have happened?" It is not a valid way to estimate the
live probability of finding alpha because the gate design was informed by
these already inspected families.

### Fresh-candidate lane

- Freeze new pair and triplet identities, categories, rationales, and registry
  order before reading their outcomes.
- Evaluate 2016-2020 TRAIN only.
- If one or more candidates pass, nominate the first pass in frozen order.
- Freeze the identity and, for triplets, the TRAIN vector.
- Run one 2021-2023 DEVELOPMENT replay.
- Keep 2024+ CONFIRMATION sealed.

The period is still called DEVELOPMENT because the project has already learned
from other 2021-2023 results. A fresh identity avoids candidate-level OOS
peeking but does not restore globally untouched confirmation evidence.

## Boundary

No gate may be changed again after these challenger outcomes are inspected.
Any further change requires a new decimal revision and a new predeclared
surface. No portfolio, allocation, intraday, live-short, or deployment scope
is opened.

The completed readout is recorded in
`GEN5_LIT_MR_02_2_03_2_RELAXED_GATE_RESULTS.md`. The fresh triplet result shows
that a candidate can pass both the relaxed and original strict conjunctions
and still fail materially OOS. Further admission-gate easing is therefore not
recommended.
