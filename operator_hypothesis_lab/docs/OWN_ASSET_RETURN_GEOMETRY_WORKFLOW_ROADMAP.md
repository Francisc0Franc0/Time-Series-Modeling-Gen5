# Own-Asset Return Geometry Workflow Roadmap

## Purpose

Turn the current TSLA descriptive microscope into a fixed, reusable workflow
that can be applied without asset-by-asset invention, then determine whether
the resulting geometry is shared across a balanced asset atlas.

This roadmap is documentation only. It does not open a new statistical gate,
parameter search, multi-asset run, or strategy implementation.

## Phase 1: Complete the TSLA Direction Lens

Use the fixed signed-ER20 state as the first causal up/down/sideways baseline.
Inspect the price bands and state behavior before applying the state to return
relationships.

Current status:

`DESCRIPTIVE_SIGNED_ER20_DIRECTION_POC_COMPLETE_FILTER_APPLICATION_NOT_YET_RUN`

## Phase 2: Freeze the Own-Asset Microscope Template

The core template should contain:

1. Adjacent-session prior-versus-following return inspection.
2. The fixed 9 by 9 prior/forward cumulative-return surface.
3. ER20 path-efficiency conditioning.
4. ATR% movement-capacity conditioning.
5. Signed-ER20 up/sideways/down conditioning.
6. Negative-prior and positive-prior branches.
7. Positive-minus-negative slope contrasts.
8. Common operator charts, tables, notes, ledgers, and explicit limitations.

QQQ/SPY predictors and other external cues remain optional extensions rather
than requirements of the own-asset core.

## Phase 3: Run a Predeclared Balanced Asset Atlas

Freeze the asset list and behavioral groups before reading results. Keep
operator-interest/high-beta names visibly separate from balancing groups such
as mature growth, cyclical/value, defensive equities, broad ETFs, and
non-equity market proxies.

Use two evidence tracks:

- **Frozen replication:** carry the TSLA-discovered `1/1`, `20/4`, `20/5`,
  and `20/10` cells unchanged into every other asset.
- **Exploratory morphology:** render the complete fixed 9 by 9 surface for each
  asset without promoting each asset's most attractive cell as a new discovery.

## Phase 4: Describe Cross-Asset Shape

Produce both asset-level and pooled views:

- common-axis small multiples;
- raw pooled scatterplots colored by asset;
- equal-asset-weighted summaries;
- past-only volatility-normalized views;
- median cell effects and same-sign asset fractions;
- behavioral-group summaries; and
- leave-one-asset-out diagnostics.

Same-date observations across assets are not independent. A pooled sample must
not be treated as though asset-session rows are unrelated replicates.

## Phase 5: Parameter and Temporal Transport Research

Only after the template is frozen and the atlas has been run should the project
open parameter selection. Three different clocks must remain distinct:

1. **Measurement clock:** prior/forward horizons, ER and ATR windows, state
   cutoffs, and any persistence or hysteresis rule.
2. **Estimation clock:** how much completed history is used to fit or select a
   model or rule.
3. **Deployment clock:** how long the frozen authority is used before the next
   evaluation or requalification.

The current `2018-2023` window is a broad exploratory surface. It is not yet a
training-window recommendation, and it gives no authority for how long the
next out-of-sample increment should be.

When this phase is opened, use a nested rolling design:

- an inner completed-history layer selects among a small predeclared parameter
  grid;
- an outer untouched time block measures transport;
- all state thresholds and normalizations are learned from completed history;
- asset-specific tuning competes against a single global parameter set; and
- selection rewards cross-asset and cross-period stability rather than the
  highest historical point estimate.

The later search space may include prior/forward horizons, signed-ER window and
cutoff, ATR window and state boundaries, training length, forward evaluation
length, and refit frequency. It must be frozen before querying the outer time
blocks, with multiplicity and repeated-selection effects handled explicitly.

## Current Stop

Do not optimize the current TSLA window, cutoff, horizons, state persistence,
training length, or forward increment while the workflow itself is still being
defined. Finish the template and atlas first so parameter research answers a
stable question rather than rescuing one inspected result.
