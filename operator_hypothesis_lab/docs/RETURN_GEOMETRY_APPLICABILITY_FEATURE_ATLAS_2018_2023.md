# Return-Geometry Applicability Feature Atlas (2018-2023 TRAIN)

## Question

The frozen next-open rebound rule did not retain broad mechanical support. This
slice asks a narrower upstream question: can clean, causal descriptors of the
loss environment visibly distinguish the historical events that subsequently
did better or worse, before fitting a model or selecting a gate?

This is exploratory feature characterization, not a strategy rescue. The rule,
trades, dates, costs, and outcome are unchanged. Post-2023 data remain sealed.

## Frozen Event and Outcome Contract

- State: signed ER20 DOWN (`<= -0.30`).
- Shock: prior-20 log return at or below the expanding 20th percentile of the
  asset's previously observed negative prior-20 returns, after at least 100
  prior negative observations.
- Execution: enter adjusted open `t+1`, exit adjusted open `t+21`, one position
  at a time, and deduct 10 bp round trip.
- Outcome: net 20-session open-to-open log return minus the same asset's
  unconditional 20-session open-to-open TRAIN drift.
- Primary surface: 1,548 events from the 88-stock, 11-sector balanced core.
- Audit surface: all 2,221 frozen-rule events from all 129 atlas instruments.

## Six Causal Feature Families

1. **Sector-relative loss** — focal prior-20 log return minus the equal-weight
   prior-20 return of the other seven stocks in its GICS sector.
2. **Peer negative breadth** — fraction of those other seven sector peers whose
   prior-20 return was negative.
3. **Abnormal dollar volume** — log ratio of event-window median adjusted-close
   dollar volume to the median over the preceding 126 sessions.
4. **Price-impact shock** — log ratio of event-window mean absolute log return
   per dollar volume to its preceding 126-session median.
5. **SPY volatility percentile** — current SPY 20-session realized volatility's
   percentile among up to 504 strictly prior observations, with at least 252
   required.
6. **Pre-shock normalized trend** — 126-session log return ending before the
   loss window, divided by daily realized volatility times `sqrt(126)`.

Every feature is available by the signal close. The focal stock is excluded
from its peer features. The current market-volatility observation is excluded
from its own reference distribution. Zero-volume bars are not treated as zero
illiquidity; 44 such rows are excluded from dollar-volume calculations.

These families follow established ideas about cross-sectional versus common
price moves, volume-conditioned reversal, illiquidity/price impact, liquidity
stress, and persistent price trends. The implementation is deliberately a
minimal proxy rather than a claim that OHLCV reconstructs latent information
or institutional liquidity:

- Lo and MacKinlay, “When Are Contrarian Profits Due to Stock Market
  Overreaction?” [doi:10.1093/rfs/3.2.175](https://doi.org/10.1093/rfs/3.2.175).
- Campbell, Grossman, and Wang, “Trading Volume and Serial Correlation in Stock
  Returns,” [doi:10.2307/2118454](https://doi.org/10.2307/2118454).
- Amihud, “Illiquidity and Stock Returns,”
  [doi:10.1016/S1386-4181(01)00024-6](https://doi.org/10.1016/S1386-4181(01)00024-6).
- Nagel, “Evaporating Liquidity,”
  [doi:10.1093/rfs/hhs066](https://doi.org/10.1093/rfs/hhs066).
- Moskowitz, Ooi, and Pedersen, “Time Series Momentum,”
  [doi:10.1016/j.jfineco.2011.11.003](https://doi.org/10.1016/j.jfineco.2011.11.003).
- Hameed and Mian, “Industries and Stock Return Reversals,”
  [doi:10.1017/S0022109014000404](https://doi.org/10.1017/S0022109014000404).

## Visual Template

Each feature receives the same first-pass treatment: event-level scatterplot
with a descriptive smooth; low-to-high bins; asset-balanced and event-pooled
means; and a concise statement of shape. Scatter axes are clipped only for
display; summaries retain every event.

## Initial Readout

No feature shows a clean monotone separator suitable for promotion from this
view alone.

- **Sector context:** the shock map remains mixed. The lowest sector-relative
  bin is positive on the asset-balanced surface, but middle bins are negative
  and event-level Spearman correlation is essentially zero (`-0.003`). Peer
  breadth is also nonmonotone. The “shared selloff is safer” intuition is not
  visually confirmed.
- **Activity:** the two highest abnormal-dollar-volume bins are negative under
  both aggregation lenses. This is compatible with unusually active losses
  containing harder-to-reverse information, but does not prove that mechanism.
- **Impact:** the highest price-impact bin is positive immediately after a
  strongly negative fourth bin. Its high-minus-low asset-balanced contrast is
  `+144 bp/trade`, but the discontinuity makes endpoint-artifact risk material.
- **Market stress:** SPY volatility-percentile bins alternate in sign; there is
  no simple high-volatility advantage.
- **Pretrend:** the profile is U-shaped. A single trend threshold would erase
  rather than clarify the observed shape.

Sector-relative loss and peer breadth are highly redundant (`rho = 0.672`).
Two post-hoc islands—the extreme sector-relative-loss bin and the highest
price-impact bin—are worth remembering only as candidates for a separately
frozen test. They are not discovered permission rules. Representative tapes
are selected within the same asset and adjacent bins by closest prior-loss
severity; outcomes never enter example selection.

## Artifacts

- Packet: `runs/research_workbench/operator_hypothesis_lab/return_geometry_applicability_feature_atlas_20260828/`
- Event ledger: `event_feature_ledger.csv`
- Construction audit: `feature_construction_checks.csv`
- Binned profiles: `asset_balanced_binned_profiles.csv`
- Interpretation ledger: `feature_interpretation.csv`
- Matched examples: `representative_matched_trade_pairs.csv`
- Running deck: `operator_hypothesis_lab/presentations/return_geometry_edge_promotion_huddle.pptx`

## Status and Boundary

`DESCRIPTIVE_FEATURE_ATLAS_COMPLETE_NO_GATE_SELECTED`

All 13 construction checks pass. This slice does not fit a classifier, compute
p-values, optimize thresholds, select features, alter the frozen rule, or open
post-2023 outcomes. If opened, the next gate should predeclare one or at most
two shapes and test held-out assets and sectors before temporal confirmation.
