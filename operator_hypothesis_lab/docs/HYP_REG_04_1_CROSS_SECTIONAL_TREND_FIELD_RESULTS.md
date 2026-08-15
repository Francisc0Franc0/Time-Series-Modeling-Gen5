# HYP-REG-04.1 Cross-Sectional Trend-Field Results

Status: `STOP_TREND_FIELD_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY`

## Question

Can a causal, equal-group field of 24 diverse ETFs provide a useful market
direction and trend-health axis before any join with asset-relative ATR% or an
asset strategy?

The field separately measured:

- cross-sectional direction;
- positive participation;
- 20/60-session trend agreement; and
- five-session improving-versus-deteriorating flow.

The primary validation asked whether those names persisted into the future
cross-section. SPY was only a secondary external direction check.

## Eventual Asset-Level Interpretation

If a future market field were promoted, it would not directly buy or sell TSLA,
AMD, or another asset. The intended architecture would be:

`market direction/health x the asset's ATR% magnitude state x an unchanged asset signal`

The market field would describe the surrounding equity environment. The
accepted `HYP-REG-01.1` ATR% state would describe whether that asset's current
directionless movement magnitude is low, medium, or high relative to its own
history. The asset strategy would still create the actual entry and exit.

This diagnostic did not authorize that join. A market sensor must first show
that it predicts its own semantics, then a separate overlay must demonstrate
that it improves unchanged strategies across assets relative to fair controls.

## Frozen Construction

Twenty-four ETFs were divided into four economic groups: broad/style/size,
sector/real assets, industry/cyclical, and international. Each asset received a
fixed volatility-normalized 20/60-session trend score. Direction was the median
of four within-group medians; participation, agreement, and flow were calculated
within group and then averaged equally across groups. SPY was excluded from the
field.

The fixed state map was:

- `BROAD_UP`: positive direction, at least 60% participation, at least 60%
  20/60 agreement, and non-negative flow;
- `FRAGILE_UP`: positive direction without the full broad-up conjunction;
- `BROAD_DOWN`: negative direction, at most 40% participation, at least 60%
  agreement, and negative flow;
- `FRAGILE_DOWN`: negative direction without the full broad-down conjunction.

No weight, horizon, threshold, or scalar composite was fitted.

## Data Admission

The first run stopped before analysis because IYT had no local history and
XHB, XRT, and KRE were partial. A bounded adjusted-daily Alpaca refresh for the
frozen 2016-2023 request produced complete coverage:

- 25/25 registry assets;
- 2,012 rows per asset;
- 503 pre-analysis sessions;
- 1,509 aligned development sessions;
- zero missing SPY-calendar sessions;
- no 2024+ rows.

The query-health `stale_symbol` labels reflect the deliberately bounded 2023
endpoint, not missing requested-window data.

## Primary State Readout

| State | Observations | Median future field H20 return | Future positive participation | Median next-open SPY H20 return |
|---|---:|---:|---:|---:|
| BROAD_UP | 429 | +0.826% | 60.83% | +1.474% |
| FRAGILE_UP | 510 | +0.769% | 61.67% | +1.447% |
| FRAGILE_DOWN | 343 | +2.015% | 76.67% | +2.421% |
| BROAD_DOWN | 207 | +2.401% | 78.33% | +2.556% |

The intended direction contrast reversed:

- `BROAD_UP` minus `BROAD_DOWN` future-field return: `-1.575 pp`;
- future-participation gap: `-17.500 pp`;
- next-open SPY H20 return gap: `-1.083 pp`.

This was not a small miss. Broadly negative fields were followed by stronger
one-month rebounds than broadly positive fields.

The positive-health distinction was effectively absent:

- `BROAD_UP` minus `FRAGILE_UP` future-field return: `+0.057 pp`;
- future-participation gap: `-0.833 pp`;
- future-negative-rate gap: `+0.378 pp`.

Adding participation, agreement, and non-negative flow to a positive direction
did not materially improve the next-month field.

## Continuous Evidence

| Measurement | Frozen future target | Spearman |
|---|---|---:|
| Direction | Future field H20 return | -0.134 |
| Participation | Future field H20 return | -0.099 |
| Flow | Future H5 participation change | +0.074 |
| Agreement | Directional persistence H20 | -0.032 |
| Direction | Next-open SPY H20 return | -0.135 |

Direction-score AUC for a positive SPY H20 outcome was `0.505`, effectively
chance. Flow had the intended positive sign but missed its 0.10 gate and was
not sufficiently monotone to rescue the field.

## Stability and Falsification

- All 20 H20 starting offsets had adequate broad-up and broad-down support.
- Only 6/20 offsets had both a positive future-field-return gap and positive
  participation gap.
- Direction gaps were jointly positive in only 1/6 calendar years.
- Positive-health gaps were jointly positive in only 2/6 years.
- Direction return/participation gaps were negative in both temporal halves.
- SPY direction gaps were also negative in both halves.
- Actual direction gaps ranked at only the 2.5th and 3.0th percentiles of the
  circular timing controls—the opposite tail from the frozen requirement.
- Positive-health gaps ranked at ordinary 44.5th and 35.0th percentiles.

The synthetic sign audit and representative ledger rows confirmed that positive
per-asset trends produced positive field scores and that next-open SPY timing
was aligned correctly. The reversal is empirical, not a sign inversion.

## Interpretation

The field is a coherent contemporaneous description, but its 20/60-session
trend inputs appear late relative to a 20-session forward target in this
development window. Broad negative configurations often occurred after enough
decline had accumulated to create a subsequent rebound; broad positive
configurations often occurred after substantial appreciation.

This does not authorize reversing the indicator into a mean-reversion filter.
It does show that a market-state descriptor is not automatically a useful
forward permission filter. A regime state intended to govern multi-week asset
strategies must persist or forecast the next relevant holding horizon; merely
describing today's cross-section is insufficient.

## Gate Decision

Only integrity passed: `1 / 9` gates.

- Record `STOP_TREND_FIELD_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY`.
- Do not invert the direction axis, alter its horizons or thresholds, join it
  to ATR%, run a TSLA/AMD strategy overlay, or inspect 2024+ under this ID.
- Preserve the latent market-mode and economic-confirmation-network concepts as
  unopened alternatives, not automatic next executions.
- Preserve point-in-time constituent breadth as a future data-authority upgrade.

## Artifacts

- Candidate map: `docs/GEN5_CROSS_SECTIONAL_MARKET_CONTEXT_CANDIDATE_MAP.md`
- Contract: `docs/GEN5_HYP_REG_04_1_CROSS_SECTIONAL_TREND_FIELD_CONTRACT.md`
- Registry: `operator_hypothesis_lab/registries/hyp_reg_04_1_cross_sectional_trend_field_registry.csv`
- Run packet: `runs/research_workbench/operator_hypothesis_lab/hyp_reg_04_1_cross_sectional_trend_field_20260814`
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_reg_04_1_cross_sectional_trend_field_evidence.pptx`
