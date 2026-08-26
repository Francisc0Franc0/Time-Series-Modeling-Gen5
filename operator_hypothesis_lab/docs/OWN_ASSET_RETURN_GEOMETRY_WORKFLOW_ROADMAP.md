# Own-Asset Return Geometry Workflow Roadmap

## Purpose

Turn the current TSLA descriptive microscope into a fixed, reusable workflow
that can be applied without asset-by-asset invention, then determine whether
the resulting geometry is shared across a balanced asset atlas.

This roadmap is documentation only. It does not open a new statistical gate,
parameter search, multi-asset run, or strategy implementation.

## Phase 1: Complete the TSLA Direction Lens

Use the fixed signed-ER20 state as the first causal up/down/sideways baseline.
Inspect the price bands and state behavior, then apply the unchanged state to
the existing return grid and prior-sign branches.

Current status:

`DESCRIPTIVE_SIGNED_ER20_GRID_COMPLETE_DOWN_REBOUND_FOUND_STOP_BEFORE_TRANSPORT`

The application is complete. UP and SIDEWAYS produced no within-state BH
survivors, while DOWN produced a broad long-prior rebound island (`18/81`) and
short-prior sign-branch separation (`17` estimable family survivors). This is a
descriptive success, but signed ER20 and prior return share trailing-path data.
The `p=20` opposite-sign UP/DOWN branches are structurally empty. Preserve the
result without tuning and carry these limitations into the template.

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

Current status:

`FROZEN_AND_TRANSPORTED_WITHOUT_ASSET_SPECIFIC_TUNING`

The atlas implementation now applies this common core to every asset and
reproduces the frozen TSLA signed-ER20 packet to below `1e-12`. Complete 9 by 9
surfaces remain descriptive; HAC/BH inference is restricted to seven
TSLA-discovered cells frozen before transport.

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

Current status:

`DESCRIPTIVE_ATLAS_COMPLETE_DOWN_REBOUND_TRANSPORTS_BROADLY_STOP_BEFORE_FINE_GRID`

The predeclared atlas contains 30 assets in six equal groups. At the frozen
signed-ER20 DOWN 20/20 cell, 23/29 transport assets share TSLA's negative
correlation sign, the transport median Pearson is `-0.1960`, and 12/29 survive
BH within that single frozen cell. The complete 15-25 by 15-25 neighborhood has
negative equal-asset medians, and every behavioral group has a negative 20/20
median. The earlier unfiltered 1/1 sign kink does not transport cleanly.

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

Initial status:

`CORE_CROSS_ASSET_SHAPE_DESCRIPTION_COMPLETE`

The packet now contains common-axis small multiples, a raw pooled scatter with
an explicit dependence warning, equal-asset and group summaries, same-sign
breadth, map similarity, and leave-one-asset-out diagnostics. The result is a
broad long-horizon DOWN-state rebound surface, not a universal prior-sign kink.

### Frozen Behavioral Vocabulary

The atlas is now also cataloged through four branch behaviors: gain
continuation, gain exhaustion, loss rebound, and loss continuation. The same
four labels apply in every conditioning state, so the method can discriminate
different behavior profiles without changing its statistical machinery or
turning every attractive cell into a new hypothesis.

Current status:

`DESCRIPTIVE_BEHAVIOR_CATALOG_COMPLETE_NO_EDGE_OR_CAUSAL_CLAIM`

Across the current atlas, loss rebound is broad in most states; gain exhaustion
is broad in trending and signed-up paths; gain continuation is conditional and
clusters most clearly in sideways paths, with a smaller low-ATR cluster; and
loss continuation is not broad. These are observed geometries and mechanism
hypotheses, not causal explanations or trading authority. The catalog should
be reused as the naming layer for future transport work: one archetype, one
conditioning state, and one predeclared horizon neighborhood at a time.

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

Do not optimize the signed-ER window, cutoff, state persistence, training
length, or forward increment. The template, atlas, and descriptive behavioral
catalog are now complete, but the next gate still belongs to the operator:
either open temporal transport of one frozen behavior/state neighborhood or
open one separately declared local horizon refinement. The atlas does not
specifically support filling the 6-9-session gap; its repeated rebound
neighborhood is approximately 15-25 prior by 15-25 following sessions.
