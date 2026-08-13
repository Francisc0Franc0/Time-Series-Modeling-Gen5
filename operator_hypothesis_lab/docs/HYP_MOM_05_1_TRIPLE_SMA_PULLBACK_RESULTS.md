# HYP-MOM-05.1 Ordered Triple-SMA Pullback/Reclaim Results

Status: `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`

## Question

What happens across the frozen 122-stock atlas when a long-only strategy:

- enters next open after a fresh `SMA15 > SMA30 > SMA45` activation with the completed close above SMA30;
- exits next open after close is at or below SMA30;
- after its first exit, re-enters only after a fresh close-above-SMA30 reclaim while the stack remains ordered; and
- holds a fixed quantity at either 1x or 1.8x gross exposure?

## Evidence boundary

- Discovery: `2021-01-04` through `2023-12-29`.
- Confirmation: `2024-01-02+`, sealed and not queried.
- Explicit as-of: `2026-08-07 17:30:00 America/New_York`.
- Registered / eligible: `122 / 120` stocks across 11 sectors.
- APHA and SNE remained incomplete after the authorized refresh and were excluded without replacement.
- The discovery window was previously inspected in other lanes, so these results are descriptive rather than fresh validation.

## Main result

At 1x, 1,099 completed trades produced:

- median asset return `-3.44%`;
- `51 / 120` positive assets;
- median Sharpe `-0.094`;
- median maximum drawdown `-15.11%`;
- median exposure `11.10%`;
- median hit rate `29.29%`; and
- median exposure-matched circular-shift percentile `35.9%`, with only `10 / 120` assets above the 80th percentile.

At fixed-quantity 1.8x, the same schedules produced median return `-7.76%`,
`43 / 120` positive assets, median maximum drawdown `-25.60%`, median financing
cost `1.44%` of initial wealth, zero 30% maintenance-proxy breaches, and zero
nonpositive-equity assets. The absence of impairment does not make leverage
attractive: both typical return and drawdown worsened.

## Failure anatomy

| Entry type | Trades | Hit rate | Median trade | Median hold |
|---|---:|---:|---:|---:|
| Initial ordered-stack activation | 120 | 43.33% | -0.714% | 16.5 sessions |
| Ordered SMA30 reclaim | 979 | 29.11% | -0.932% | 3 sessions |

The median per-asset whipsaw fraction was `83.33%` under the frozen
`<=20-session` diagnostic. Immediate reclaims therefore behaved more like
short-lived noise than durable trend resumption in this window.

## Annual breadth

The 1x median calendar return was `+1.04%` in 2021 (`67 / 120` positive),
`-2.73%` in 2022 (`26 / 120` positive), and `-0.94%` in 2023 (`31 / 120`
positive). Median exposure fell from `16.67%` in 2021 to about `4%` in each of
2022 and 2023. The weakness therefore spans both the broad 2022 decline and
the 2023 rebound; it is not solely a consequence of one bearish year.

## Baselines

At 1x, median excess return was `-23.46` percentage points versus buy-and-hold,
`-11.86` points versus SMA30-only, and `-0.09` points versus ordered-stack-only.
At 1.8x it beat ordered-stack-only by `+6.10` points but remained negative in
absolute terms. This reflects reduced exposure to a leveraged baseline, not
repaired timing evidence.

## Representative tapes

- O: near-median return, `-3.45%`, 10 trades, 6.65% exposure.
- META: highest return, `+138.03%`, 14 trades, 40.56% exposure.
- SNAP: lowest return, `-36.60%`, 10 trades.
- SPCE: deepest 1x drawdown, `-55.34%`, despite `+6.63%` final return.
- PEP: highest trade count, 20 trades and `+1.11%` return.
- DOW: distinct high-reclaim-share example, 17 trades and `+3.59%` return.

The tapes are behavioral examples, not asset-selection nominees.

## Decision

Record `WIDE_DISCOVERY_COMPLETE_NO_PROMOTION_AUTHORITY`.

Do not access confirmation, tune 15/30/45, select favorable assets or sectors,
or treat 1.8x as useful leverage evidence under this identifier. The valuable
lesson is narrower: an ordered trend stack plus an immediate SMA30 reclaim is
not sufficient re-entry evidence here. Any delay, persistence requirement,
slope filter, volatility normalization, or moving-average change is a new
theory-first mechanic requiring a new frozen lane and distinct evidence.

## Artifacts

- Contract: `operator_hypothesis_lab/docs/HYP_MOM_05_1_TRIPLE_SMA_PULLBACK_CONTRACT.md`
- Engine: `operator_hypothesis_lab/R/hyp_mom_05_1_triple_sma_pullback.R`
- Runner: `operator_hypothesis_lab/scripts/run_hyp_mom_05_1_triple_sma_pullback_wide_discovery.R`
- Tests: `operator_hypothesis_lab/tests/testthat/test_hyp_mom_05_1_triple_sma_pullback.R`
- Evidence deck: `operator_hypothesis_lab/presentations/hyp_mom_05_1_triple_sma_pullback_wide_discovery_evidence.pptx`
- Ignored packet: `runs/research_workbench/operator_hypothesis_lab/hyp_mom_05_1_triple_sma_pullback_wide_discovery_20260812/`
