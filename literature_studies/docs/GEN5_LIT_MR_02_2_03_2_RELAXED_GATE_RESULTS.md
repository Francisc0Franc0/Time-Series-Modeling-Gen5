# LIT-MR-02.2 And LIT-MR-03.2 Relaxed-Gate Research Results

## Status

`RESEARCH_COMPLETE_NO_FURTHER_GATE_RELAXATION_RECOMMENDED`

## Executive Readout

Measured gate easing increased retrospective admissions but did not produce a
robust new OOS result.

- One of 44 retrospective pairs passed `02.2`; its DEVELOPMENT bar-level
  return was negative.
- Zero of 20 fresh pairs passed `02.2`.
- Two of 36 retrospective triplets passed `03.2`; both were cost-fragile in
  DEVELOPMENT.
- One of 20 frozen fresh triplets passed `03.2`. It also passed every original
  strict `03.1` gate, then failed materially in DEVELOPMENT.

The evidence does not say the gates were too conservative. It says TRAIN
structure and convergence evidence can fail to persist across time.

## Pair Retrospective Lane

Status:
`RETROSPECTIVE_DESCRIPTIVE_COMPLETE_LIT_MR_02_2`.

The deterministic retrospective union contained 44 unique prior pairs.

- Strict full passes: `0 / 44`.
- Relaxed full passes: `1 / 44`.
- Survivor: `SIL-SLV`.

TRAIN `SIL-SLV` evidence:

- 69 completed trades;
- mean primary-cost return `+56.82 bp/trade`;
- bootstrap q10 `+2.96 bp/trade`;
- random-sign p90 `+41.36 bp/trade`;
- forward correlation `-0.1153`;
- convergence q90 `-0.0357`; and
- six of six relaxed mandatory rules.

Its descriptive 2021-2023 DEVELOPMENT replay produced:

- 47 completed trades;
- mean completed-trade return `+7.70 bp`;
- hit rate `63.8%`;
- cumulative primary-cost bar return `-1.36%`;
- stress-cost return `-7.94%`;
- adjusted Sharpe `0.013`; and
- maximum drawdown `-16.34%`.

The positive trade mean and hit rate did not translate into positive bar-level
compounding after dynamic rehedging and costs. This is a concrete reason to
retain both trade-level and bar-level evaluation.

Packet:
`runs/research_workbench/literature_grounded/lit_mr_02_2_retrospective_20260729`.

## Pair Fresh Atlas 01

Status:
`STOP_LIT_MR_02_2_FRESH_ATLAS_01_NO_PASS`.

- Frozen candidates: `20`.
- Relaxed full passes: `0 / 20`.
- Return q10 passes: `0 / 20`.
- Random-sign p90 passes: `1 / 20`.
- Convergence q90 passes: `1 / 20`.
- DEVELOPMENT replays: `0`.

`XOM-CVX` reached four of six relaxed gates. It had a positive return point
estimate but failed 95% positive-beta coverage, the return q10 rule, and the
full conjunction. It was not promoted.

Packet:
`runs/research_workbench/literature_grounded/lit_mr_02_2_fresh_atlas_01_20260729`.

## Triplet Retrospective Lane

Status:
`RETROSPECTIVE_DESCRIPTIVE_COMPLETE_LIT_MR_03_2`.

Two of 36 prior triplets passed the relaxed conjunction:

1. `EWA-EWC-IGE`, newly admitted because its convergence q90 was below zero
   even though its stricter 97.5th-percentile bound was not; and
2. `EWA-EWC-EWZ`, the prior strict survivor.

`EWA-EWC-IGE` DEVELOPMENT:

- 55 completed trades;
- mean return `+1.34 bp/trade`;
- hit rate `70.9%`;
- cumulative primary-cost return `+0.38%`;
- stress-cost return `-6.13%`;
- adjusted Sharpe `0.059`; and
- maximum drawdown `-5.24%`.

`EWA-EWC-EWZ` DEVELOPMENT:

- 57 completed trades;
- mean return `+8.50 bp/trade`;
- hit rate `71.9%`;
- cumulative primary-cost return `+3.73%`;
- stress-cost return `-3.23%`;
- adjusted Sharpe `0.317`; and
- maximum drawdown `-5.88%`.

The added relaxed survivor was economically weaker than the strict survivor.

Packet:
`runs/research_workbench/literature_grounded/lit_mr_03_2_retrospective_20260729`.

## Triplet Fresh Atlas 01

Status:
`OOS_DEVELOPMENT_COMPLETE_LIT_MR_03_2_FRESH_ATLAS_01`.

Three frozen candidates were retained as coverage-ineligible failures:

- `VOO-IVV-SPLG` because `SPLG` lacked exact requested-session coverage;
- `XME-PICK-REMX` because `REMX` lacked exact requested-session coverage; and
- `LQD-VCIT-IGIB` because `IGIB` lacked exact requested-session coverage.

They were not replaced. Seventeen candidates received full TRAIN analysis.

The sole relaxed pass was `UNP-CSX-NSC`. It also passed the original strict
eight-gate conjunction.

TRAIN:

- vector \([1,\ 1.9028871,\ -1.0922300]\);
- exact rank one;
- vector cosine `0.9828`;
- half-life `14.75` sessions;
- 84 completed trades;
- mean return `+31.08 bp/trade`;
- bootstrap q10 `+15.26 bp/trade`;
- hit rate `70.2%`;
- forward correlation `-0.1046`; and
- convergence q90 `-0.0460`.

The identity and vector were frozen before the one authorized DEVELOPMENT
replay.

DEVELOPMENT:

- 40 completed trades;
- mean return `-36.19 bp/trade`;
- hit rate `52.5%`;
- forward correlation `+0.0143`;
- cumulative primary-cost return `-14.25%`;
- stress-cost return `-18.68%`;
- adjusted Sharpe `-0.870`; and
- maximum drawdown `-19.02%`.

This is a clean relationship-break example. The failure cannot be blamed on
the eased cosine, half-life, support, or uncertainty thresholds because the
candidate also cleared every strict gate.

Packet:
`runs/research_workbench/literature_grounded/lit_mr_03_2_fresh_atlas_01_20260729`.

## Recommendation

Do not loosen the current pair or triplet gates further.

The next high-signal theory question is whether a relationship that passes a
long TRAIN window should be requalified through time before and during
DEVELOPMENT. Possible future concepts include:

- rolling or expanding structural requalification;
- explicit coefficient-drift and rank-break monitoring;
- a predeclared no-trade state when the relationship no longer qualifies; and
- comparison against a frozen always-trade relationship control.

That would be a new strategy or risk-control revision. It is not authorized by
this result.

## Boundary

- All `02.1` and `03.1` results remain immutable.
- Retrospective results remain descriptive and post-hoc.
- Fresh DEVELOPMENT results are not confirmation.
- 2024+ remains sealed.
- No portfolio, allocation, intraday, live-short, or deployment scope opens.
