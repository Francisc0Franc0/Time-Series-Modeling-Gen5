# HYP-REG-10.1 Multi-Horizon Direction Agreement Results

Status: `STOP_MULTI_HORIZON_AGREEMENT_STRATEGY_GATES_FAILED_CONFIRMATION_NOT_RUN`

## Question

Can full agreement across fixed 20-, 60-, and 120-session
volatility-normalized price directions improve fresh next-open entries in the
unchanged daily SMA8/SMA14 long/cash parent?

## Evidence Boundary

- Evidence label: `DEVELOPMENT_REUSED_WINDOW`.
- Analysis: 2018-01-02 through 2023-12-29.
- Panel: 24 primary stocks plus SPY and QQQ references.
- Confirmation: 2024-01-02 onward remained sealed.
- No horizon, threshold, state, asset, parent, ATR, leverage, or exit search was
  performed.

## Construction

For each fixed horizon `h = 20, 60, 120`, the lane measures log-price
displacement divided by realized log-return volatility scaled by `sqrt(h)`.
The sign of each normalized displacement supplies direction. `FULL_UP` means
all three signs are positive; `FULL_DOWN` means all are negative. Two explicit
opposition states preserve cases where the 20-session direction differs from
an aligned 60/120-session context.

The nested horizons are correlated descriptions of one path. Agreement is not
three independent observations, three p-values, or tripled confidence.

## Stage A — Measurement Readout

All 7/7 frozen construction gates passed:

- complete 26/26 coverage, at least 503 prehistory sessions, and no 2024+ rows;
- 100% intended-state recovery for seeded clean-up, clean-down,
  short-opposes-up, and short-opposes-down paths;
- 860 real-panel `SHORT_JOINS_UP` and 349 `SHORT_JOINS_DOWN` events with exact
  transition semantics;
- price-scale invariance within `4e-15` and exact append invariance;
- zero state or `FULL_UP`-eligibility semantic violations;
- 24/24 primary stocks met the frozen state and policy usability thresholds;
- median `FULL_UP` eligibility occupied 39.2% of analysis sessions.

This establishes a coherent causal measurement. It does not establish a
useful strategy gate.

## Stage B — Strategy Readout

The unchanged SMA8/SMA14 parent reproduced all 156 annual asset cells within
`4.44e-15`. The `ENTRY_FULL_UP_ONLY` policy passed 3/9 strategy gates:

| Metric | Parent | `FULL_UP` entry gate |
|---|---:|---:|
| Median annual return | 8.95% | -0.68% |
| Median maximum drawdown | -14.59% | -7.69% |
| Median Sharpe | 0.642 | -0.203 |
| Median exposure | 53.88% | 17.50% |
| Median turnover | 19.67 | 6.09 |

Only 1/24 primary stocks improved over the six-year compound and only 1/6
development years had positive median excess. The actual gate ranked at the
12.5th percentile of 40 exposure-nearest circular timing controls and trailed
their median by 0.68 percentage points.

The parent-trade audit explains the failure behaviorally. The 495 entries whose
signal-date state was `FULL_UP` had a 42.4% hit rate and a -0.71% median trade,
weaker than the other entry-state groups. Full cross-horizon alignment may
often arrive after a move is mature, but that interpretation remains a lesson
from this stopped policy rather than authority to invert or retune it.

## Decision

Retain the causal multi-horizon state ledger and its opposition/join semantics
as descriptive research infrastructure. Stop the hard `FULL_UP` entry policy.
Do not rescue it by changing 20/60/120, adding magnitude thresholds, using a
majority-up rule, trading join events, selecting assets or years, stacking
ATR%, changing the parent or exit, adding leverage, or accessing 2024+.

The next roadmap gate is discussion of T4 causal change-point onset. It is not
opened by this result.

After T1–T5, if no candidate earns promotion, discuss an HMM lane from
literature first. Inventory operator-provided PDFs and primary sources, then
freeze observable inputs, state-count discipline, causal filtered rather than
retrospectively smoothed state probabilities, label interpretation, and
held-out validation before implementation.

## Artifacts

- Contract: `docs/GEN5_HYP_REG_10_1_MULTI_HORIZON_AGREEMENT_CONTRACT.md`.
- Engine: `operator_hypothesis_lab/R/hyp_reg_10_1_multi_horizon_agreement_poc.R`.
- Runner: `operator_hypothesis_lab/scripts/run_hyp_reg_10_1_multi_horizon_agreement_poc.R`.
- Registry: `operator_hypothesis_lab/registries/hyp_reg_10_1_multi_horizon_agreement_registry.csv`.
- Evidence deck:
  `operator_hypothesis_lab/presentations/hyp_reg_10_1_multi_horizon_agreement_evidence.pptx`.
- Ignored packet:
  `runs/research_workbench/operator_hypothesis_lab/hyp_reg_10_1_multi_horizon_agreement_20260816`.
