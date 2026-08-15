# HYP-REG-04.2 Fast Cross-Sectional Trend-Impulse Results

Status: `STOP_FAST_TREND_IMPULSE_GATES_FAILED_NO_CONFIRMATION_ATR_JOIN_OR_STRATEGY`

## Question

The preceding 20/60-session market field described the recent tape but did not
preserve its direction into the next month. This derivative-development lane
asked whether a more reactive measurement could detect a newly broadening move
early enough for its direction and participation to persist over H5 and H10.

The test did not select among a speed grid. It froze five-session direction and
participation, the five-session change in participation, and a 20-session
direction used only to label continuation versus reversal.

## Causal Construction

For each of 24 ETFs, five- and 20-session log returns were normalized by the
preceding 63-session daily volatility ending at `t-1`. The four economic groups
from `HYP-REG-04.1` received equal weight.

- `D5`: median of the four within-group median normalized H5 returns.
- `P5`: equal-group fraction with positive normalized H5 return.
- `I5 = P5_t - P5_t-5`: five-session participation impulse.
- `D20`: medium context, used only to label continuation versus reversal.

`BROAD_UP_IMPULSE` required positive `D5`, at least 60% participation, and
positive `I5`. `BROAD_DOWN_IMPULSE` was the symmetric negative state. Signals
were known after close `t`; SPY targets began at the next open.

The 2018-2023 period had already been inspected in prior work and is explicitly
derivative development evidence. The 2024+ confirmation seal remained intact.

## Data Admission

The existing bounded Alpaca adjusted-daily cache supplied complete coverage:

- 25/25 registry assets complete;
- 24/24 field inputs on every admitted row;
- 1,509 common analysis sessions;
- no imputation and no 2024+ rows.

## Primary H5 Result

| Contrast | State A / B rows | Field-return gap | Future-participation gap | Negative-rate gap | SPY gap |
|---|---:|---:|---:|---:|---:|
| Broad-up impulse minus broad-down impulse | 541 / 444 | +0.058 pp | +0.833 pp | -2.393 pp | -0.082 pp |
| Broad-up impulse minus other-up | 541 / 325 | +0.198 pp | +5.833 pp | -1.919 pp | +0.235 pp |

The primary direction contrast was economically tiny and missed both frozen
semantic thresholds by a wide margin. A broad negative impulse was not reliably
followed by a negative five-session field move.

The positive-impulse contrast was the one local clue: broad-up impulse rows had
about +0.20 percentage points more H5 field return and +5.83 points more future
participation than other positive-direction rows. However, the negative-rate
improvement was only 1.92 points, and the full conjunctive gate failed.

## Continuous Evidence

| Measurement | Frozen future target | Spearman / AUC |
|---|---|---:|
| Fast direction `D5` | Future H5 field return | -0.024 |
| Fast participation `P5` | Future H5 field return | -0.008 |
| Participation impulse `I5` | Future H5 participation change | -0.477 |
| 5/20 alignment | H5 directional persistence | +0.020 |
| Fast direction `D5` | Future H10 field return | -0.025 |
| Fast direction `D5` | Future H20 field return | -0.036 |
| Fast direction `D5` | Next-open SPY H5 return | -0.030 |
| Fast direction `D5` | SPY H5-UP AUC | 0.525 |

The faster direction measurement did not order subsequent returns at any
reported horizon. The strong negative impulse coefficient means that a large
five-session expansion in participation was usually followed by participation
cooling during the next five sessions.

That coefficient must be interpreted carefully. Consecutive changes
`P_t-P_t-5` and `P_t+5-P_t` share `P_t` with opposite signs, and participation
is bounded between zero and one. This intentionally stringent continuity
target therefore contains an algebraic tendency toward negative association as
well as empirical mean reversion. It still answers the frozen question: the
observed broadening did not continue reliably. It does not prove a tradable
contrarian rule.

## Durability, Transport, and Falsification

- H10 direction field-return gap: `-0.247 pp`.
- H10 future-participation gap: `-8.750 pp`.
- H20 decay field-return gap: `-0.249 pp`.
- H5 offsets jointly positive: `2 / 5`.
- H10 offsets jointly positive: `2 / 10`; the first two were positive and the
  remaining eight had negative return and participation gaps.
- H5 direction gaps were jointly positive in only `2 / 6` calendar years.
- Positive-impulse gaps were jointly positive in only `2 / 6` years.
- Both temporal halves had slightly negative direction return gaps.
- Direction timing ranked only at the `52.5th` return and `49.5th`
  participation percentiles of circular controls.
- The positive-impulse clue ranked at the `86.5th` and `87.5th` percentiles,
  below the complete gate and unsupported by calendar durability.

The 20-session context label was descriptive rather than decisive. Upward
continuations had somewhat better sign-aligned H5 returns than upward
reversals, but negative continuations remained negative on a sign-aligned
basis. Alignment/persistence correlation was only `+0.020`.

## Gate Decision

Only integrity passed: `1 / 10` gates.

Record
`STOP_FAST_TREND_IMPULSE_GATES_FAILED_NO_CONFIRMATION_ATR_JOIN_OR_STRATEGY`.

Do not:

- shorten the window again under this identifier;
- select the favorable positive-impulse slice;
- reverse the participation-impulse result into a mean-reversion rule;
- tune thresholds or scan speed combinations;
- join ATR%, run a TSLA/AMD or other strategy overlay, or inspect 2024+.

## Interpretation

The test distinguishes latency from a deeper limitation. The earlier 20/60
field was slow, but the five-session field was not a reliable forward direction
sensor either. Reactivity reduced lag while increasing noise and did not create
stable signed-return persistence.

The accepted ATR% result remains conceptually different: volatility magnitude
clusters, whereas signed direction is much harder to forecast. These results
support setting down simple window-shortening as a direction-filter research
path. A future market-context lane should change the information source or the
predicted property, not merely make the same price/breadth construction faster.

## Artifacts

- Contract: `docs/GEN5_HYP_REG_04_2_FAST_CROSS_SECTIONAL_TREND_IMPULSE_CONTRACT.md`
- Registry: `operator_hypothesis_lab/registries/hyp_reg_04_2_fast_cross_sectional_trend_impulse_registry.csv`
- Runner: `operator_hypothesis_lab/scripts/run_hyp_reg_04_2_fast_cross_sectional_trend_impulse.R`
- Packet: `runs/research_workbench/operator_hypothesis_lab/hyp_reg_04_2_fast_cross_sectional_trend_impulse_20260815`
