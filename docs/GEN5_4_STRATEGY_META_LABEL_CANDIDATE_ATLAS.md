# Gen5.4 Strategy Meta-Label Candidate Atlas

## Purpose

Gen5.4 direct next-return modeling did not produce enough reliable OOS ranking or
participation discrimination to justify further threshold or model tuning. This
inspection branch asks a more bounded question:

> Does an established raw strategy family have a repeatable conditional advantage
> over buy-and-hold that could later be used as the target for a meta-label gate?

The raw strategy remains the candidate generator. A future meta-label, if earned,
would decide whether to permit a candidate signal; it would not replace its entry
or exit semantics with a generic next-return forecast.

## MS-P0: Raw Candidate State Map

### Fixed mechanics

- Adjusted daily OHLCV and explicit historical `as_of_timestamp`.
- Five high-beta symbols: `AMD,NVDA,TSLA,MSTR,AVGO`.
- Eight quarters of rolling TRAIN and four fixed 91-day OOS folds per named
  annual window.
- Long-only, next-open execution and existing portfolio-independent WFA replay.
- Strategy-family selection and parameters use TRAIN only.
- No live bridge files, authority, advice, allocation, leverage, or order behavior
  are touched.

### Candidate families

`ema_cross`, `ema_trend`, `bollinger_touch`, `bollinger_mid_reversion`,
`rsi_mr`, `zret_mr`, `breakout`, and `pullback_in_uptrend` are each tested alone
  against `no_trade` and `no_trade_exit_immediate` inside their normal WFA
  candidate surface. The EMA-trend grid is deliberately broadened to all valid combinations
of fast `1,5,10,15,20` and slow `10,15,20,50,75` periods.

### Common inspection state map

For each symbol and fold, the TRAIN-only median 20-session return and realized
20-session volatility define a simple 2x2 state map:

- `trend_confirmed` / `trend_weak`
- `vol_quiet` / `vol_elevated`

The audit reports raw daily strategy-minus-hold return and raw long exposure in
each OOS state. These are descriptive diagnostics, not state inputs to the
strategy, model fitting, or selection policy.

## Promotion Rule

MS-P0 can only nominate a family for an MS-P1 meta-label POC if its conditional
behavior is sufficiently stable across windows: a coherent state-level relative
edge, an understandable exposure mechanism, and no dependence on a single symbol
or year. It does not establish alpha, allocation evidence, or a production
trading policy.

If no family clears that bar, stop and diagnose raw strategy/benchmark behavior
instead of adding ML complexity.

## Artifact Surface

The completed atlas is assembled under:

`runs/research_workbench/meta_label_candidate_atlas/ms_p0_candidate_atlas_2020_2024/`

It includes an explicit run catalog, raw asset summaries, daily state labels,
family/window and family/state summaries, heatmaps, and paths to the existing
strategy/equity trade tapes.

## MS-P0 Readout And Stop

The completed 40-packet atlas did not promote a family to MS-P1. `breakout` was
the least-negative raw family on the five-window aggregate, but it still lagged
hold overall and did not show a stable relative-edge story across symbols and
windows. The other families were weaker on the same descriptive comparison.

The shared 2x2 map did reveal a consistent defensive pattern: weak-trend cells
often showed positive strategy-minus-hold daily results because several families
reduced long exposure there. But every family lagged hold in the confirmed-trend
cells in this deliberately coarse map. That is useful diagnosis, not evidence
that the map itself supplies a tradeable gate.

STOP: do not fit a generic MS-P1 meta-label from this state map. A future gate
must start from a predeclared candidate-specific payoff target and signal-time
features, then demonstrate repeatable improvement against its raw candidate.
