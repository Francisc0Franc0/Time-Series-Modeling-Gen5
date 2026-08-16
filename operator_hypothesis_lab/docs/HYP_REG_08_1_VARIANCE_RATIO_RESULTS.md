# HYP-REG-08.1 Rolling Variance-Ratio Persistence Results

Status: `STOP_VARIANCE_RATIO_STRATEGY_RELATIVE_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Plain-Language Readout

The variance-ratio measurement worked. It correctly distinguished synthetic
reversing, random-walk-like, and persistent return processes; remained causal
when future rows were appended; and produced usable `LOW`, `MEDIUM`, and
`HIGH` states across the real panel.

The approved strategy use did not work. Requiring `HIGH` before every fresh
SMA8/SMA14 entry rejected so many opportunities that the median annual
asset-year stayed in cash. The gate did not select better parent trades and
did not beat calendar-preserving timing controls.

## Stage A — Measurement Passed 7/7

- IID median VR(5): `1.000`; robust 5% rejection: `4.7%`.
- Heteroskedastic IID median VR(5): `0.993`; robust rejection: `5.9%`.
- Negative-autocorrelation median VR(5): `0.779`; only `3.7%` exceeded one.
- Positive-autocorrelation median VR(5): `1.277`; `95.4%` exceeded one.
- Append-invariance maximum difference: `0`.
- Signed-state violations: `0`.
- `22 / 24` strategy stocks had at least 5% occupancy in both `HIGH` and
  `LOW`; median occupancy was `37.0% / 43.3% / 20.9%` for
  `LOW / MEDIUM / HIGH`.

The first finite state was 2018-01-03. Earlier state rows remained unavailable
because the provider supplied 503 rather than the preferred 550 prehistory
sessions; the two frozen 252-session windows were not changed.

## Stage B — Strategy Passed 3/9

The exact parent reproduced all `156 / 156` annual cells with a maximum
difference of `4.44e-15`.

At 5 bp per side:

- parent median annual return: `8.95%`;
- `HIGH`-only overlay median annual return: `0.00%`;
- overlay median exposure: `0.00%`;
- parent trades: `1,394`; overlay trades: `256`;
- assets improving over six years: `1 / 24`;
- years with positive median excess: `1 / 6`;
- timing-control percentile: `50th`, with `0.00%` actual and
  exposure-nearest-control median return;
- drawdown improved by `14.59` percentage points, but overlay Sharpe was
  `0.497` lower than the parent.

The parent-trade audit rejected the intended selection mechanism. Trades
entered in `HIGH` had a `44.1%` hit rate and `-0.43%` median return. Trades
entered in `LOW` had a `48.3%` hit rate. `HIGH` did not rank entry quality.

## Decision

Retain the causal Lo-MacKinlay implementation and its state diagnostics as a
measurement artifact. Set down the hard `HIGH`-only SMA entry gate. Do not
tune thresholds, switch to VR(10), select UNH or 2018, soften the gate, stack
ATR%, change the strategy, or inspect 2024+ under this identifier.

The next roadmap concept is T2 volatility-normalized robust slope and fit. It
asks a different trend-quality question and requires a separate discussion and
freeze before implementation.

## Artifacts

- Contract: `docs/GEN5_HYP_REG_08_1_VARIANCE_RATIO_CONTRACT.md`.
- Runner: `operator_hypothesis_lab/scripts/run_hyp_reg_08_1_variance_ratio_poc.R`.
- Registry: `operator_hypothesis_lab/registries/hyp_reg_08_1_variance_ratio_registry.csv`.
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_reg_08_1_variance_ratio_persistence_evidence.pptx`.
- Ignored evidence packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_reg_08_1_variance_ratio_20260816`.
