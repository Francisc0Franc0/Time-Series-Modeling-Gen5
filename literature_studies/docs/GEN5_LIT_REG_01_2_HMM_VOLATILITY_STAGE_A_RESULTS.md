# LIT-REG-01.2 HMM Volatility-State Stage A Results

Status: `STOP_LIT_REG_01_2_REFERENCE_OR_SYNTHETIC_GATES_FAILED_MARKET_DATA_NOT_READ`

Date executed: 2026-08-19

## Bottom Line

The volatility-only two-state HMM passed five of eight frozen reference and
synthetic gates. It recovered every clearly separated two-state simulation
with excellent causal state accuracy and transition estimates. It did not,
however, reliably turn weak or genuinely one-state simulations into the
required explicit abstention. Thirty-six of 60 cases ended as numerical
failures, so the conjunctive Stage A gate stopped the exercise before any
market data were read.

This is a qualification failure, not a market or strategy null. It establishes
that `HiddenMarkov` 1.8-14 plus the independent Gen5 recursion can identify
clear Gaussian volatility states, but not that the frozen estimation and
abstention architecture is dependable when two states are weakly identified
or absent.

## Evidence Boundary

- `market_data_read=FALSE`
- `confirmation_data_read=FALSE`
- `strategy_data_read=FALSE`
- No Alpaca request, SPY bar, 2024+ observation, return direction, trading
  rule, Sharpe ratio, drawdown, or P&L entered this run.
- Stages B and C were structurally not executed.

## Frozen Stage A Scorecard

| Gate | Result | Observed evidence |
|---:|---|---|
| A1 | `PASS` | `HiddenMarkov` 1.8-14 available; package/Gen5 likelihood difference `8.88e-16`. |
| A2 | `PASS` | Maximum deterministic replay difference `0`. |
| A3 | `PASS` | Append difference `0`; smoothing revised history by `0.000149`, confirming the causal/retrospective distinction. |
| A4 | `PASS` | Strong cases promoted `20/20`; median filtered-state accuracy `0.991`, tenth percentile `0.988`. |
| A5 | `PASS` | Strong-case median maximum transition error `0.0108`; ninetieth percentile `0.0210`. |
| A6 | `FAIL` | Weak cases abstained only `3/20`, versus `14/20` required. Entropy and confidence still moved in the expected direction. |
| A7 | `FAIL` | Null cases abstained only `1/20`, versus `18/20` required; none was incorrectly promoted. |
| A8 | `FAIL` | `36` numerical failures; only `24/60` cases received one of the two valid scientific classifications. |

The eight gates were conjunctive. Five passes cannot compensate for one
failure, so the market-data boundary remained closed.

## What Worked

The reference implementation and the explicit Gen5 forward recursion agreed
to numerical precision on the frozen likelihood check. Repeated runs were
exactly deterministic, and appending future observations did not revise prior
filtered probabilities. Retrospective smoothing did revise history, which is
why smoothing and Viterbi paths remain hindsight-only diagnostics.

All 20 strong simulations produced `VALID_TWO_STATE_MODEL`. Their median
causal state accuracy was 99.1%, and the transition-matrix recovery error was
small. This is the intended positive control: when persistent Gaussian states
are genuinely present and clearly separated, the frozen model can recover
them.

The uncertainty diagnostics also behaved qualitatively sensibly. Mean
posterior entropy rose from `0.024` in strong cases to `0.435` in weak cases,
and mean maximum confidence fell by `0.193`. The failure was not that the model
was oblivious to ambiguity; it was that the estimation path too often failed
before ambiguity could be represented as a valid abstention.

## What Failed

| Fixture class | Valid two-state | Explicit abstention | Numerical failure |
|---|---:|---:|---:|
| Strong | 20 | 0 | 0 |
| Weak | 0 | 3 | 17 |
| Null | 0 | 1 | 19 |

Among the 720 H2 reference starts, the recorded convergence codes were:

- strong: `240 CONVERGED`;
- weak: `94 CONVERGED`, `101 INVALID_PARAMETERS`, `45 MAX_ITERATIONS`;
- null: `29 CONVERGED`, `77 INVALID_PARAMETERS`, `134 MAX_ITERATIONS`.

Some weak and null H2 starts converged, but each case also required a valid
two-component mixture comparator before the abstention logic could make a
scientific classification. The current packet does not persist comparator-
specific diagnostics, so it would be incorrect to assign every case-level
failure to H2 alone.

## Implementation Note

The first completed fitting pass exposed a reporter-schema defect: cases with
no valid selected fit did not carry the expected `selected` column. No gate
table was produced from that attempt. The reporter was fixed, a regression
test was added, and the exact frozen workload was rerun without changing
fixtures, starts, seeds, thresholds, or gates. The rerun above is the sole
authoritative evidence.

## Interpretation and STOP

The appropriate conclusion is narrow:

1. clear persistent two-state Gaussian volatility processes are recoverable;
2. weak and absent state structure remains both a statistical-identifiability
   and numerical-reliability problem under this frozen architecture;
3. a mature reference package does not remove the need for an explicit and
   operationally reliable no-regime outcome; and
4. no claim about SPY, cross-asset volatility states, volatility forecasting,
   regime-conditioned trading, or directional HMMs was tested.

Do not rescue `LIT-REG-01.2` by changing estimators, starts, tolerances,
fixtures, thresholds, comparators, or abstention rules after reading these
outcomes. A different robust-estimation or model-selection architecture would
require a separately discussed and frozen substantive variant. The distinct
`LIT-REG-02.1` directional track remains bookmarked and unfrozen.

## Evidence Packet

Authoritative packet:
`runs/research_workbench/literature_studies/lit_reg_01_2_hmm_stage_a_20260819`

Key files:

- `stage_a_gates.csv`
- `status_by_fixture_class.csv`
- `synthetic_case_summary.csv`
- `reference_fit_diagnostics.csv`
- `reference_likelihood_crosscheck.csv`
- `determinism_causality_checks.csv`
- `stage_a_report.md`
- `verdict.txt`
