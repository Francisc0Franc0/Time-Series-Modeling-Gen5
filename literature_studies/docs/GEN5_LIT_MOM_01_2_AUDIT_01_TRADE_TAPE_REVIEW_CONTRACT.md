# LIT-MOM-01.2 Audit 01: Representative Trade-Tape Review Contract

Status: `FROZEN_BEFORE_INDIVIDUAL_TAPE_INSPECTION`

Evidence label: `RETROSPECTIVE_DESCRIPTIVE_TRADE_TAPE_REVIEW`

## Question

What did the already audited `LIT-MOM-01.2` policy look like through time in a
deliberately varied set of assets, and what mechanical or behavioral questions
become visible when entries, exits, cash gaps, drawdowns, trade outcomes, and
buy-and-hold paths are shown together?

## Authority and boundary

This is a human-readable addendum to
`LIT-MOM-01.2 / AUDIT_01_EXPOSURE_AND_SELECTION`. It changes no signal,
horizon, execution, cost, universe, provider, outcome window, portfolio rule,
or live behavior.

- Input packet:
  `runs/research_workbench/literature_grounded/lit_mom_01_2_audit_01_exposure_selection_20260802`
- Retrospective window: 2021-01-04 through 2023-12-29.
- Confirmation remains sealed from 2024-01-02.
- All tapes use the frozen selected policy and primary 5 bp-per-side costs.
- Selection is explicitly outcome-aware and descriptive. The sample cannot be
  used to estimate incidence, nominate assets, or validate a filter.

## Frozen eight-archetype selection

The selection helper must return exactly one unique symbol for each archetype.
Ties break lexicographically by symbol after the stated score. If an earlier
archetype already used a symbol, the next eligible symbol advances.

1. `SHY_TUTORIAL`
   - Select SHY deterministically as the worked mechanics and cost-fragility
     anchor.
2. `CROSS_SECTIONAL_MEDOID`
   - Among 113 stocks, minimize robust-scaled squared distance from the median
     on selected return, excess versus buy-and-hold, excess versus constant
     exposure, random percentile, maximum drawdown, and SPY beta.
3. `POSITIVE_BUT_EXPOSURE_DOMINATED`
   - Require positive selected return, negative excess versus buy-and-hold,
     and negative excess versus constant exposure.
   - Choose the robust multivariate medoid of eligible paths on selected
     return, both excess measures, random percentile, drawdown, and beta.
4. `ATTRIBUTION_SURVIVOR`
   - Require positive excess versus buy-and-hold, positive excess versus
     constant exposure, random percentile at least 80%, and positive annualized
     SPY intercept.
   - Maximize the minimum cross-sectional percentile rank across those four
     attribution measures. This favors balanced evidence rather than one
     spectacular metric.
5. `RANDOM_TIMING_DISAPPOINTMENT`
   - Require positive selected return and random percentile at most 20%.
   - Choose the eligible robust medoid on selected return, excess versus
     constant exposure, drawdown, and beta.
6. `DEEP_DRAWDOWN_POSITIVE_FINISH`
   - Require positive selected return and maximum drawdown at or below the
     stock cross-section's tenth percentile.
   - Choose the eligible robust medoid on selected return, excess versus
     buy-and-hold, random percentile, and beta.
7. `ATTENTION_COHORT_MEDOID`
   - Restrict to the frozen `RETAIL_ATTENTION_2020` cohort and choose its robust
     medoid on selected return, both excess measures, random percentile,
     drawdown, and beta.
8. `COUNTERCYCLICAL_TRADE_MIX`
   - Require at least ten executed trades whose signal occurred in a positive
     SPY 60-session trend and at least ten in a non-positive trend.
   - Maximize mean trade return in the non-positive state minus mean trade
     return in the positive state.

## Tape design

Every tape must show the complete retrospective window and contain:

- selected-strategy and buy-and-hold normalized wealth;
- selected and buy-and-hold drawdowns;
- every executed trade's entry-to-exit interval, colored by profitable or
  losing outcome;
- every trade return at its exit date, with signal-state markers for positive
  versus non-positive SPY trend; and
- the frozen `L/H`, trade count, calendar participation, selected return,
  buy-and-hold return, excess versus constant exposure, random percentile,
  maximum drawdown, SPY beta, and annualized intercept.

## Interpretation discipline

- A visually compelling tape does not override the 2/11 Audit 01 scorecard.
- Selected tapes are examples, not cross-sectional frequency estimates.
- Local visual patterns may generate questions but cannot become filters on
  the inspected 2021-2023 data.
- Observations must distinguish mechanics, path dependence, exposure capture,
  timing, drawdown, and state coincidence.
- Any later challenger requires a separately justified and frozen contract.
