# HYP-REG-05.1 Path Trendability Diagnostic — Results

## Decision

Record
`STOP_PATH_TRENDABILITY_GATES_FAILED_NO_ATR_JOIN_OR_STRATEGY`.

Kaufman Efficiency Ratio and Wilder ADX are useful descriptions of the path
that has just occurred, but neither one robustly identified assets whose next
10 or 20 sessions would follow a straighter, more persistent path. ADX formed
the more operationally usable historical states; ER supplied one interesting
direction-survival clue. Neither distinction was sufficient for promotion.

## What was tested

The frozen development panel contains 26 assets and 1,509 sessions per asset
from 2018-01-02 through 2023-12-29. The 2024+ interval remained sealed. Every
signal used information available at the signal close, while every future path
began at the next open.

The primary candidate was Kaufman's 20-session Efficiency Ratio:

```text
ER20_t = |C_t - C_(t-20)| / sum(i=t-19..t) |C_i - C_(i-1)|
```

ER approaches one when price travels directly from its starting point to its
ending point and approaches zero when the same net displacement contains many
reversals. The benchmark was Wilder ADX(14), built from directional movement,
true range, Wilder smoothing, and the absolute separation between `+DI` and
`-DI`. ADX measures trend strength, not direction. Five-session ADX change was
reported only as a descriptive secondary diagnostic.

Both indicators were converted to causal, asset-relative percentiles using
only their prior 252 valid values. The same 30/40/60/70 hysteresis thresholds
used in the accepted ATR% diagnostic created `LOW`, `MEDIUM`, and `HIGH`
states without fitting cutoffs to outcomes.

The primary future target was path efficiency over H10:

```text
future_efficiency(t,H) =
  |log(C_(t+H) / O_(t+1))| /
  sum of absolute log-price steps from O_(t+1) through C_(t+H)
```

Direction survival and future turn rate were secondary semantic checks. H5
tested onset and H20 tested durability. The gate stack also required asset
breadth, non-overlapping-offset stability, temporal transport, superiority to
within-asset/year circular timing controls, and usable state dynamics.

## Primary readout

| Candidate | H10 median per-asset rho | Assets with positive rho | HIGH/LOW future-efficiency ratio | Gates passed |
|---|---:|---:|---:|---:|
| ER20 | -0.023 | 6 / 26 | 0.956x | 1 / 9 |
| ADX14 | -0.049 | 8 / 26 | 0.966x | 2 / 9 |

At H20, ER's median rho was `+0.003` and its HIGH/LOW ratio was `1.016x`;
ADX's values were `-0.035` and `0.984x`. Neither horizon supplied a stable
positive ordering. Across all ten H10 non-overlapping offsets, neither
candidate produced a single offset with both positive median rho and a
HIGH/LOW ratio above one.

Temporal transport also failed. Both temporal halves were unfavorable for
both indicators; ER was jointly favorable in only one of six calendar years
and ADX in none. In the circular-control test, the actual H10 alignment was at
approximately the `0.5th` rho percentile for ER and the `0th` percentile for
ADX. The apparent timing was therefore not better than the preserved-calendar
pseudo-signals in the required favorable direction.

## The useful distinctions

ER's HIGH state had a `+5.5 percentage-point` direction-survival gap over its
LOW state, positive in `20 / 26` assets. That is a genuine descriptive clue:
a recently efficient path was somewhat more likely to retain its sign. It did
not, however, lead to a more efficient future path. HIGH ER paths had a lower
H10 future-efficiency ratio, offset results were unstable, and circular timing
was strongly unfavorable. Direction survival alone is not the construct this
lane froze.

ADX passed the state-usability gate. Its states occupied roughly one-third of
the sample each, switched about 14 times per year, had a median run length of
11.5 sessions, and showed no one-session reversals. ER switched about 54 times
per year, had a three-session median run, and reversed after one session about
15.5% of the time. ADX is therefore the cleaner historical regime label, but
its clean labels did not predict forward trendability. Rising ADX also showed
mixed asset-level relationships and no stable panel result.

## Interpretation and boundary

This is not evidence that ADX or ER is "bad," nor evidence that either should
be inverted into a mean-reversion strategy. It is evidence against this
specific use: a causal, asset-relative ADX14 or ER20 state did not reliably
forecast a straighter next-open H10/H20 path across the frozen panel.

Do not tune indicator lengths or hysteresis after inspection, select favorable
assets or years, join either indicator to ATR%, run a strategy overlay, compute
strategy performance, or access 2024+ under this identifier. A variance-ratio
diagnostic remains a conceptually serious but separately governed future
question because it tests multi-scale return dependence rather than re-labeling
this stopped result.

## Evidence

- Frozen contract:
  `docs/GEN5_HYP_REG_05_1_PATH_TRENDABILITY_DIAGNOSTIC_CONTRACT.md`
- Run packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_reg_05_1_path_trendability_20260815`
- Evidence deck:
  `operator_hypothesis_lab/presentations/hyp_reg_05_1_path_trendability_evidence.pptx`
