# HYP-MOM-01.1 Stock Atlas 02 Breadth Extension Results

Status: `DISCOVERY_BREADTH_EXTENSION_COMPLETE_NO_STRATEGY_AUTHORITY`

Evidence stage: `DISCOVERY_REUSED_WINDOW`

Run packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_01_1_stock_atlas_02_breadth_extension_20260804/`

## Question

Does the behavior observed in the original 22-asset HYP-MOM-01.1 discovery
and Diagnostic Atlas 01 persist when the same frozen rule and the same
diagnostics are applied to a much wider, independently registered stock atlas?

This is a breadth audit of an already inspected 2021-2023 window. It is not an
untouched validation test and cannot promote a filter, strategy, or live rule.

## Frozen design

The parent strategy was not changed:

- signal: two consecutive completed daily bars, each opening above the prior
  close and closing above its own open;
- signal observation: after the second bar closes;
- entry: next session open;
- exit: the open five sessions after entry;
- exposure: long-only, full notional within each separately evaluated asset;
- overlap: one position per asset, with same-open re-entry allowed after an
  exit;
- costs: 5 bp per side primary and 10 bp per side stress;
- discovery window: 2021-01-04 through 2023-12-29;
- panel length: 1,000 matched market sessions per eligible asset;
- confirmation: 2024 and later remained excluded.

The 100-name registry was reused from the previously frozen
`LIT-MOM-01.2` breadth-attention atlas. It contained 75 diversified-core and
25 2020 retail-attention names across 11 sectors, with no overlap with the
original HYP-MOM-01.1 panel. Reusing that pre-outcome registry avoids inventing
a new universe after seeing this lane's results.

Each new asset had to have every required discovery session, at least 220
prior sessions for the SMA200 and lagged diagnostics, and valid positive finite
adjusted OHLCV. No failed symbol was replaced.

## Coverage and provenance

Ninety-four of the 100 additions passed. Combined with the original 22, the
merged pool contains 116 assets and 4,015 nonoverlapping trades.

| Registry cohort | Registered | Eligible | Excluded |
|---|---:|---:|---:|
| Diversified core | 75 | 74 | 1 |
| Retail attention 2020 | 25 | 20 | 5 |
| Atlas 02 total | 100 | 94 | 6 |
| Original plus eligible Atlas 02 | 122 | 116 | 6 |

The six exclusions were preserved rather than silently backfilled:

- `DOW`, `NIO`, and `ADT`: invalid adjusted OHLCV in the required material;
- `APHA` and `SNE`: incomplete discovery-window symbol history;
- `LI`: only 108 usable prior sessions, below the frozen 220-session minimum.

The refreshed provider-health surface still reports historical
`partial_history`, `refresh_needed`, and `stale_symbol` warnings because the
explicit as-of timestamp is in 2026 while this bounded query ends in 2023, and
because several registry names have structural listing or ticker-history
limits. For every one of the 94 analyzed additions, the requested discovery
calendar and prehistory gate passed. Refreshing did not change eligibility or
results. The warnings remain visible in the packet and are not interpreted as
missing in-window evidence for eligible assets.

## Strategy-level readout

| Panel | Assets | Trades | Mean trade | Median trade | Hit rate | Median asset return | Positive at 5 bp/side | Beat buy-and-hold | Median random percentile |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Original 22 | 22 | 821 | -0.018% | +0.157% | 52.62% | -0.994% | 11 | 1 | 34.25% |
| Atlas 02 | 94 | 3,194 | -0.033% | +0.187% | 52.35% | -0.037% | 47 | 33 | 43.50% |
| Combined | 116 | 4,015 | -0.030% | +0.181% | 52.40% | -0.037% | 58 | 34 | 43.05% |

The wider panel strengthens the original economic diagnosis. The pattern wins
slightly more often than it loses and has a positive median trade, but the
losing tail is larger than the winning tail. Combined mean winners were
`+3.09%`; mean nonpositive trades were `-3.47%`; the fifth and ninety-fifth
percentiles were `-7.37%` and `+6.54%`. The combined mean trade therefore
remained negative after primary costs.

Only 34 of 116 assets beat their own buy-and-hold return over the discovery
window, and the median asset ranked at the 43.05th percentile of its matched
random-entry controls. The rule does not show a generic timing advantage over
ordinary ownership or matched random timing.

## Did the original diagnostic candidates persist?

The primary diagnostic estimand is the equal-asset mean of each asset's own
conditional-return contrast. This prevents high-frequency signal generators
from dominating a pooled trade average.

| Diagnostic contrast | Original 22 | New Atlas 02 | Combined | Combined 95% bootstrap interval | Combined assets positive |
|---|---:|---:|---:|---:|---:|
| Large minus small normalized gap | +0.477 pp | -0.038 pp | +0.011 pp | [-0.472, +0.493] | 53.45% |
| Large minus small normalized body | -0.070 pp | -0.162 pp | -0.144 pp | [-0.494, +0.226] | 44.83% |
| Above versus below asset SMA200 | -0.269 pp | -0.122 pp | -0.151 pp | [-0.539, +0.208] | 47.37% |
| Positive versus nonpositive 20-session return | +0.143 pp | +0.131 pp | +0.133 pp | [-0.239, +0.497] | 52.59% |
| SPY above versus below SMA200 | +0.571 pp | +0.061 pp | +0.158 pp | [-0.147, +0.459] | 56.03% |
| Positive versus nonpositive SPY 60-session return | +0.591 pp | +0.226 pp | +0.313 pp | [-0.029, +0.710] | 45.69% |

Every interval crosses zero and the sign breadth remains close to half. The
two original candidates that looked most interesting—gap size and SPY above
its SMA200—shrank sharply in the new 94-asset panel. SPY trend context remains
descriptively better on a point-estimate basis, but it no longer warrants a
replication lane from this evidence alone.

The continuous within-asset Spearman correlations tell the same story. The
largest combined median correlation was only `+0.026` for 20-session momentum;
gap size was `-0.007`, body size was `-0.011`, and 60-session momentum was
`-0.053`. None shows a useful monotonic gradient.

The nine-cell normalized-gap by normalized-body surface was also
nonmonotonic. For example, the high-body row ranged from `-0.07%` to `+0.21%`,
while the low-body row ranged from `+0.01%` to `+0.34%`. This is not a stable
"stronger candles are better" relationship and no cell should be selected
after inspection.

## Why pooled and equal-asset views can disagree

The combined pooled trades above the asset SMA200 averaged `+0.064%`, compared
with `-0.181%` below it. Yet the equal-asset above-minus-below contrast was
`-0.151` percentage points.

This sign reversal is not a contradiction. A pooled average weights an asset
in proportion to how many signals it generated, so frequent-signal assets can
dominate the answer. The equal-asset calculation first estimates the contrast
inside each asset and then gives each asset one vote. Because the research
question asks whether a condition generalizes across assets, the equal-asset
view is primary and the pooled view is diagnostic.

## What happens after entry?

The original small panel suggested that some early losers recovered. That
behavior did not produce a stable exit rule in the combined evidence.

| Checkpoint | Mean remaining return after positive state | Mean remaining return after nonpositive state | Equal-asset difference | 95% interval |
|---|---:|---:|---:|---:|
| After day 1 | +0.028% | +0.059% | -0.046 pp | [-0.357, +0.269] |
| After day 2 | +0.128% | -0.034% | +0.138 pp | [-0.151, +0.412] |
| After day 3 | +0.113% | -0.127% | +0.238 pp | [-0.002, +0.494] |
| After day 4 | -0.013% | +0.028% | -0.051 pp | [-0.205, +0.094] |

Current unrealized P&L strongly describes the final trade outcome, but its
incremental prediction of the *remaining* return is small, unstable, and
changes sign. Day 3 is a near miss in an already reused discovery window, not
authority for a stop, add, or continuation rule.

## Cohort and sector context

The diversified-core additions averaged `+0.159%` per trade, while the frozen
2020 retail-attention cohort averaged `-0.826%`; their median asset returns
were `+1.11%` and `-24.64%`, respectively. The attention cohort contained much
of the extreme downside tail.

This is useful heterogeneity, but not a validated selection rule. The two
cohorts were intentionally built for different purposes and differ in sector,
listing age, volatility, and survivor/history availability. Similarly, the
sector summaries are descriptive and must not be mined into post-hoc filters.

## Trade-tape audit

Six frozen representative tapes make the behavior concrete:

- `C`: pooled medoid, nearly flat despite a large two-candle body;
- `CGC`: best trade, a violent rebound from a long downtrend;
- `PLUG`: worst trade, a continuation collapse after an apparently strong
  gap pattern;
- `PSA`: SPY-above medoid, modestly positive in an established trend;
- `ABBV`: SPY-below medoid, essentially flat;
- `NUE`: high-gap/high-body medoid, essentially flat despite strong-looking
  candles.

The best and worst tapes both occurred while SPY was above its SMA200, and the
high-gap/high-body tape was ordinary. These examples are illustrations of the
quantitative result, not substitutes for it.

## Decision

Record `DISCOVERY_BREADTH_EXTENSION_COMPLETE_NO_STRATEGY_AUTHORITY`.

The breadth extension was worthwhile because it changed the interpretation of
the 22-asset audit. The positive median and slight majority hit rate are real
features of the sample, but they coexist with a worse loss tail, negative mean
expectancy, weak ownership and random-timing controls, and diagnostic effects
that do not generalize across the added assets.

No observed filter should be promoted or tuned from this pool. In particular,
do not open a SPY-SMA200 replication merely because it was the strongest
candidate in the original panel; breadth reduced its new-panel contrast to
`+0.061` percentage points. A future continuation would need a new economic
question, a frozen rule, and genuinely distinct evidence—not another threshold
search inside these 116 assets and the same 2021-2023 window.

2024 and later data remain untouched for this lane. No portfolio, allocation,
live-advice, or execution behavior is authorized.
