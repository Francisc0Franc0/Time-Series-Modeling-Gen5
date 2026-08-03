# HYP-MOM-01.1 Diagnostic Atlas 01 Results

Status: `DIAGNOSTIC_ATLAS_COMPLETE_NO_STRATEGY_AUTHORITY`

Evidence stage: `DISCOVERY_REUSED_WINDOW`

Parent strategy: `HYP-MOM-01.1`

## Bottom line

None of the predeclared signal-shape, asset-trend, prior-return, volume, or
price-location conditions produced broad and stable separation across the 22
assets. The popular intuition that this pattern should work better above the
asset's 200-session average was not supported. Stronger prior asset momentum
was also inconsistent across 20-, 60-, and 120-session lookbacks.

Two findings are worth retaining as questions:

1. larger volatility-scaled gaps improved the pooled high-versus-low point
   estimate, but the middle tercile was stronger than the high tercile, only
   half of assets agreed, and the asset-bootstrap interval crossed zero; and
2. the pattern behaved better when SPY was above its own SMA200, especially in
   the left tail, but the contrast was not conclusive and is confounded with
   the small number of market regimes in 2021-2023.

The within-trade audit also pushes against a naive early stop. Trades that were
down after one or two sessions recovered more, on average, over the remaining
holding period than trades already in profit—although they usually did not
recover enough to erase the initial deficit.

## Integrity and scope

All nine integrity checks passed. The atlas retained the original 821 executed
trades across 22 stocks and eleven sectors. It used the complete 2016-2023
Alpaca adjusted-daily history to compute causal lagged volatility, SMA200, and
lookback features, but conditional outcomes remained restricted to the frozen
2021-2023 discovery interval. Every 2024+ observation remained excluded.

The parent signal, next-open entry, five-session exit, costs, reinvestment,
and non-overlap policy did not change.

## Candle and gap properties

Gaps and bodies were expressed in strictly lagged 20-session close-return
volatility units. Pooled rank terciles were descriptive visual bins rather than
executable thresholds.

| Condition | Trades | Mean trade | Median trade | Hit rate |
|---|---:|---:|---:|---:|
| Low gap strength | 273 | -0.377% | -0.055% | 49.5% |
| Mid gap strength | 274 | +0.197% | +0.322% | 54.4% |
| High gap strength | 274 | +0.125% | +0.236% | 54.0% |
| Low body strength | 273 | -0.117% | -0.055% | 49.5% |
| Mid body strength | 274 | -0.046% | +0.185% | 52.9% |
| High body strength | 274 | +0.109% | +0.314% | 55.5% |

The equal-asset high-minus-low gap contrast was `+0.477` percentage points,
but its bootstrap interval was `[-0.184, +1.155]`; the median asset contrast
was only `+0.034` points and exactly `11 / 22` assets were positive. The
high-minus-low body contrast was only `+0.056` points with interval
`[-0.708, +0.750]`.

The complete 3 x 3 grid was nonmonotonic. For example, the mid-gap/high-body
cell had the highest point estimate (`+0.746%`, 87 trades), while the
low-gap/high-body cell had the lowest (`-0.773%`, 74 trades). Selecting either
cell would be outcome mining. Per-asset continuous correlations were also
small: median Spearman rho was `+0.047` for gap strength and `+0.021` for body
strength.

Interpretation: very small patterns may be weak, but the data do not support a
universal “larger is better” threshold.

## Asset SMA200 location

| Signal state | Trades | Mean trade | Median trade | Hit rate | 5th percentile |
|---|---:|---:|---:|---:|---:|
| Below SMA200 | 227 | +0.044% | +0.290% | 53.7% | -6.71% |
| Recent reclaim | 95 | -0.039% | +0.085% | 52.6% | -5.36% |
| Established above | 499 | -0.042% | +0.118% | 52.1% | -4.85% |

Established-above minus below produced an equal-asset contrast of `-0.269`
percentage points with interval `[-0.828, +0.272]`; only `8 / 22` asset
contrasts were positive. Recent-reclaim minus below was `-0.653` points with
interval `[-1.680, +0.193]`, and only `7 / 21` were positive.

Being below the anchor did not create a clean advantage either. It produced
both a wider upside and a materially worse loss tail. Established-above and
recent-reclaim trades were more compressed, not more profitable. The median
within-asset correlation between continuous anchor distance and trade return
was `-0.126`, positive in only `6 / 22` assets.

Interpretation: this sample looks more compatible with volatile rebound
behavior than with a simple “already above SMA200 means better momentum” rule,
but it does not validate a below-anchor reversal filter.

## Prior-return lookbacks

| Lookback | Positive-state mean | Nonpositive-state mean | Equal-asset contrast | Bootstrap interval |
|---|---:|---:|---:|---:|
| 20 sessions | -0.009% | -0.035% | +0.012 pp | [-0.443, +0.486] pp |
| 60 sessions | -0.063% | +0.062% | -0.150 pp | [-0.687, +0.454] pp |
| 120 sessions | +0.041% | -0.151% | +0.132 pp | [-0.338, +0.600] pp |

The signs disagree across horizons and none has a stable asset-level contrast.
Median per-asset Spearman rho was `-0.009`, `-0.121`, and `-0.051` for the
20-, 60-, and 120-session returns respectively.

Interpretation: adding an `L`-period positive-return requirement is not
supported by this discovery atlas.

## Secondary conditions

- Only 15 executed trades followed runs of three or more qualifying sessions;
  their mean was `-0.443%`. That is too little support for a maturity rule.
- Above-median signal-day volume had a `+0.013%` mean versus `-0.052%` below
  median, but the equal-asset contrast was `+0.127` points with interval
  `[-0.398, +0.682]` and fewer than half of assets agreed.
- Near-60-session-high trades averaged `+0.019%`; mid-range and far-below
  trades averaged `-0.068%` and `-0.027%`. The near-minus-far asset contrast
  was only `+0.059` points with interval `[-0.355, +0.444]`.

None warrants a filter.

## Broad-market context

| SPY state at signal | Trades | Mean trade | Median trade | Hit rate | 5th percentile |
|---|---:|---:|---:|---:|---:|
| Above SMA200 | 591 | +0.137% | +0.231% | 54.1% | -4.41% |
| Below SMA200 | 230 | -0.417% | -0.146% | 48.7% | -8.38% |

The equal-asset above-minus-below contrast was `+0.571` percentage points;
`13 / 22` assets agreed and the interval was `[-0.083, +1.286]`. This was the
clearest economically coherent contrast, but it still crossed zero and the
below-SMA200 sample is heavily entangled with the difficult 2022 regime.

SPY's 60-session return sign did not reproduce the same breadth: its contrast
was `+0.175` points with interval `[-0.479, +0.899]`, and only `10 / 22` assets
were positive. The possible effect therefore looks more like a slow market
regime or tail-risk condition than a generic positive-return filter.

Interpretation: SPY-above-SMA200 is the strongest candidate for a later,
separately frozen replication question. It is not an accepted `01.2` filter.

## Within-trade checkpoint behavior

| Checkpoint | Currently nonpositive: mean remaining | Currently positive: mean remaining | Positive minus nonpositive asset contrast |
|---|---:|---:|---:|
| After session 1 | +0.207% | +0.054% | -0.246 pp |
| After session 2 | +0.273% | +0.014% | -0.293 pp |
| After session 3 | +0.044% | +0.112% | +0.048 pp |
| After session 4 | +0.131% | +0.052% | -0.075 pp |

After sessions one and two, losing trades had more average recovery left than
winning trades. The day-two contrast was negative in `16 / 22` assets and its
bootstrap interval nearly reached zero on the upper side
(`[-0.588, +0.014]` points).

However, currently losing trades still finished with mean final returns of
`-1.12%`, `-1.56%`, `-2.18%`, and `-2.42%` at checkpoints one through four.
The recovery was not enough to restore them. A stop might reduce tail risk but
would also surrender average recovery; this atlas cannot choose that tradeoff.

## Recommendation

Do not create a multi-filter strategy from the inspected cells. Specifically:

- do not add asset-SMA200 or positive-`L` requirements;
- do not choose the best gap/body grid cell;
- do not infer that a simple early-loss stop improves expectancy; and
- do not use the low-support three-session run result.

If one lean next question is opened, the best-supported choice is a new
`HYP-MOM-01.2` replication contract asking whether **broad-market permission
defined by SPY above its SMA200** reduces the loss tail on a distinct frozen
asset or time sample. Pattern strength is a serious alternative, but it should
be expressed as one monotonic, volatility-scaled hypothesis and not as the
best cell from this grid.

## Artifacts

- Frozen contract:
  `operator_hypothesis_lab/docs/HYP_MOM_01_1_DIAGNOSTIC_ATLAS_01_CONTRACT.md`
- Frozen diagnostic registry:
  `operator_hypothesis_lab/registries/hyp_mom_01_1_diagnostic_atlas_01_registry.csv`
- Reproducible runner:
  `operator_hypothesis_lab/scripts/run_hyp_mom_01_1_diagnostic_atlas_01.R`
- Human-facing evidence deck:
  `operator_hypothesis_lab/presentations/hyp_mom_01_1_diagnostic_atlas_01_evidence.pptx`
- Ignored evidence packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_mom_01_1_diagnostic_atlas_01_20260803/`
